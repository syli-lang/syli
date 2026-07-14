open Syli_core.Core_ast
open Syli_ir.Cir
module C = Syli_core.Core_ast
module I = Syli_ir.Cir
open Syli_common
module CA = Syli_core.Closure_analysis

exception Lowering_error of string

(* ================================================================== *)
(*  Lowering context                                                  *)
(* ================================================================== *)

type env = I.var StringMap.t

type ctx = {
  locals : I.var list;
  current_stmts : I.statement list;
  blocks : I.block list;
  lifted_fns : I.function_cir list;
  env : env;
  toplevel_functions : int StringMap.t;
  analysis : CA.core_closure_analysis;
  tmp_counter : int ref;
  block_counter : int ref;
  pending_merge_id : int option;
}

let empty_analysis : CA.core_closure_analysis =
  { CA.closure_infos = Hashtbl.create 0 }

let empty_ctx =
  {
    locals = [];
    current_stmts = [];
    blocks = [];
    lifted_fns = [];
    env = StringMap.empty;
    toplevel_functions = StringMap.empty;
    analysis = empty_analysis;
    tmp_counter = ref 0;
    block_counter = ref 0;
    pending_merge_id = None;
  }

let fresh_id = Syli_ir.Cir.fresh_id

let fresh_var_with_name (ctx : ctx) (name : string) (ty : I.ty) : ctx * I.var =
  let v : I.var = { I.id = fresh_id (); I.name; I.ty } in
  ({ ctx with locals = v :: ctx.locals }, v)

let fresh_var (ctx : ctx) (ty : I.ty) : ctx * I.var =
  let idx = !(ctx.tmp_counter) in
  ctx.tmp_counter := idx + 1;
  let v : I.var =
    { I.id = fresh_id (); I.name = "Sy_var" ^ string_of_int idx; I.ty }
  in
  ({ ctx with locals = v :: ctx.locals }, v)

let env_add_var ctx (var : var) =
  { ctx with env = StringMap.add var.I.name var ctx.env }

let env_mem_var ctx (id : C.ident) = StringMap.mem id.fullname ctx.env
let env_find_var_opt ctx (id : C.ident) = StringMap.find_opt id.fullname ctx.env

let emit (ctx : ctx) (node : I.statement_node) (ty : I.ty) : ctx * I.statement =
  let id = fresh_id () in
  let s = { I.id; node; ty } in
  ({ ctx with current_stmts = s :: ctx.current_stmts }, s)

let finish_block (ctx : ctx) (term_node : I.terminator_node) : ctx =
  let block_id =
    match ctx.pending_merge_id with Some id -> id | None -> fresh_id ()
  in
  let block : I.block =
    {
      I.id = block_id;
      I.label_id = !(ctx.block_counter);
      statements = List.rev ctx.current_stmts;
      terminator = { I.id = fresh_id (); node = term_node };
      pred_blocks = [];
      succ_blocks = [];
    }
  in
  incr ctx.block_counter;
  {
    ctx with
    pending_merge_id = None;
    blocks = block :: ctx.blocks;
    current_stmts = [];
  }

let finish_block_with_id (ctx : ctx) (id : I.id) (term_node : I.terminator_node)
    : ctx =
  let block : I.block =
    {
      I.id;
      I.label_id = !(ctx.block_counter);
      statements = List.rev ctx.current_stmts;
      terminator = { I.id = fresh_id (); node = term_node };
      pred_blocks = [];
      succ_blocks = [];
    }
  in
  incr ctx.block_counter;
  { ctx with blocks = block :: ctx.blocks; current_stmts = [] }

let assign_cast_var new_v src_v to_ty =
  I.CR_Assign
    {
      dst = new_v;
      rvalue =
        {
          I.id = fresh_id ();
          node = I.CR_Cast { src = I.CR_OVar src_v; to_ty };
          ty = to_ty;
        };
    }

(* =================================================== *)
(*  Type / operator helpers                            *)
(* =================================================== *)

let mk_ir_ty (cty : C.ty) : I.ty =
  let rec go (t : C.ty) : I.ir_type =
    match t.ty_desc with
    | CTy_Constant c -> (
        match c with
        | CTy_Int64 -> I.CR_I64
        | CTy_Int32 -> I.CR_I32
        | CTy_Int16 -> I.CR_I16
        | CTy_Int8 -> I.CR_I8
        | CTy_UInt64 -> I.CR_U64
        | CTy_UInt32 -> I.CR_U32
        | CTy_UInt16 -> I.CR_U16
        | CTy_UInt8 -> I.CR_U8
        | CTy_Unit -> I.CR_Void
        | CTy_Bool -> I.CR_Bool
        | CTy_Float -> I.CR_Float
        | CTy_Double -> I.CR_Double
        | CTy_StringLit -> I.CR_Obj { named = Some "string"; args = [] }
        | CTy_CharLit -> I.CR_I8)
    | CTy_Var v -> I.CR_GenericTyp { type_var = v }
    | CTy_Arrow (args, ret) ->
        I.CR_Arrow
          ( List.map (fun t -> { I.id = fresh_id (); I.ir_type = go t }) args,
            { I.id = fresh_id (); I.ir_type = go ret } )
    | CTy_Tuple _ -> I.CR_Obj { named = None; args = [] }
    | CTy_Array _ -> I.CR_Obj { named = None; args = [] }
    | CTy_Defined _ -> I.CR_Obj { named = None; args = [] }
  in
  { I.id = fresh_id (); I.ir_type = go cty }

let rec ir_type_equal (a : I.ir_type) (b : I.ir_type) : bool =
  match (a, b) with
  | CR_Bool, CR_Bool -> true
  | CR_I64, CR_I64 -> true
  | CR_I32, CR_I32 -> true
  | CR_I16, CR_I16 -> true
  | CR_I8, CR_I8 -> true
  | CR_U64, CR_U64 -> true
  | CR_U32, CR_U32 -> true
  | CR_U16, CR_U16 -> true
  | CR_U8, CR_U8 -> true
  | CR_Float, CR_Float -> true
  | CR_Double, CR_Double -> true
  | CR_FnPtr, CR_FnPtr -> true
  | CR_Void, CR_Void -> true
  | CR_GenericTyp { type_var = tv1 }, CR_GenericTyp { type_var = tv2 } ->
      tv1 = tv2
  | CR_Obj { named = n1; args = args1 }, CR_Obj { named = n2; args = args2 } ->
      n1 = n2 && List.for_all2 ty_equal args1 args2
  | CR_Ptr t1, CR_Ptr t2 -> ty_equal t1 t2
  | CR_Arrow (args1, ret1), CR_Arrow (args2, ret2) ->
      List.for_all2 ty_equal args1 args2 && ty_equal ret1 ret2
  | _, _ -> false

and ty_equal (a : I.ty) (b : I.ty) : bool =
  ir_type_equal a.I.ir_type b.I.ir_type

let ir_const_of_core = function
  | CConst_Unit -> I.CR_Null
  | CConst_IntLit s -> I.CR_IntLit s
  | CConst_FloatLit s -> I.CR_FloatLit s
  | CConst_BoolLit s -> I.CR_BoolLit s
  | CConst_StringLit s -> I.CR_StringLit s
  | CConst_CharLit s -> I.CR_CharLit s

let binop_of_core (op : C.binop) : I.binop =
  match op with
  | CBinop_Arithmetic a -> (
      match a with
      | CAdd -> I.CR_Add
      | CSub -> I.CR_Sub
      | CMul -> I.CR_Mul
      | CDiv -> I.CR_Div
      | CMod -> I.CR_Mod)
  | CBinop_Logical l -> ( match l with CAnd -> I.CR_And | COr -> I.CR_Or)
  | CBinop_Bitwise b -> (
      match b with
      | CBitAnd -> I.CR_BitAnd
      | CBitOr -> I.CR_BitOr
      | CBitXor -> I.CR_BitXor
      | CLShift -> I.CR_Shl
      | CRShift -> I.CR_Shr)
  | CBinop_Comparison c -> (
      match c with
      | CEq -> I.CR_Eq
      | CNe -> I.CR_Ne
      | CLt -> I.CR_Lt
      | CLe -> I.CR_Le
      | CGt -> I.CR_Gt
      | CGe -> I.CR_Ge)

let unop_of_core (op : C.unop) : I.unop =
  match op with
  | CUnop_Arithmetic C.CNeg -> I.CR_Neg
  | CUnop_Logical C.CNot -> I.CR_Not
  | CUnop_Bitwise C.CBitNot -> I.CR_BitNot

let void_ir_ty : I.ty = { I.id = 0; I.ir_type = I.CR_Void }
let void_null = I.CR_OConstant (I.CR_Null, void_ir_ty)

let arg_ty_of_operand = function
  | I.CR_OConstant (_, ty) -> ty
  | I.CR_OVar v -> v.I.ty

let get_args_ty ty =
  match ty.C.ty_desc with CTy_Arrow (args, _) -> args | _ -> []

let lower_closure_apply (ctx : ctx) (closure_var : I.var)
    (closure_fun_ty : C.ty) (concrete_arg_ops : I.operand list) (out_ty : I.ty)
    : ctx * I.operand =
  let ctx, concrete_closure_var = (ctx, closure_var) in
  let ctx, call_dst, result =
    let ctx, dst = fresh_var ctx out_ty in
    (ctx, dst, I.CR_OVar dst)
  in
  let ctx, _ =
    if List.length (get_args_ty closure_fun_ty) = List.length concrete_arg_ops
    then
      emit ctx
        (I.CR_Call
           {
             dst = call_dst;
             target = I.Apply { closure = concrete_closure_var };
             args = concrete_arg_ops;
           })
        out_ty
    else
      emit ctx
        (I.CR_Partial_apply
           {
             dst = call_dst;
             closure = concrete_closure_var;
             new_args = concrete_arg_ops;
           })
        out_ty
  in
  (ctx, result)

let collect_toplevel_functions (prog : C.program_core) : int StringMap.t =
  List.fold_left
    (fun acc (item : C.structure_item) ->
      match item.structure_item_desc with
      | CStr_Let { name; value; _ } -> (
          match value.node with
          | CExp_Lambda lam ->
              StringMap.add name.fullname (List.length lam.params) acc
          | _ -> acc)
      | _ -> acc)
    StringMap.empty prog.C.structure_items

(* ================================================================== *)
(*  Expression lowering                                               *)
(* ================================================================== *)

let rec lower_expr (ctx : ctx) (e : C.expr) : ctx * I.operand =
  let out_ty = mk_ir_ty e.ty in
  match e.node with
  | CExp_Constant c -> (ctx, I.CR_OConstant (ir_const_of_core c, out_ty))
  | CExp_Ident id -> (
      match StringMap.find_opt id.fullname ctx.env with
      | Some v when StringMap.mem id.fullname ctx.toplevel_functions ->
          let ctx, closure_var = fresh_var ctx out_ty in
          let ctx, _ =
            emit ctx
              (I.CR_Make_closure
                 {
                   dst = closure_var;
                   fn = id.fullname;
                   free_vars = [];
                   captured_args = [];
                   initializer_fn = None;
                 })
              out_ty
          in
          (ctx, I.CR_OVar closure_var)
      | Some v -> (ctx, I.CR_OVar v)
      | None ->
          raise
            (Lowering_error
               (Printf.sprintf
                  "Unbound identifier during Core->SIR lowering: %s" id.fullname))
      )
  | CExp_UnOp (op, x) ->
      let ctx, ox = lower_expr ctx x in
      let ctx, dst = fresh_var ctx out_ty in
      let rv : I.rvalue =
        {
          I.id = dst.I.id;
          node = I.CR_UnOp { op = unop_of_core op; operand = ox };
          ty = out_ty;
        }
      in
      let ctx, _ = emit ctx (I.CR_Assign { dst; rvalue = rv }) out_ty in
      (ctx, I.CR_OVar dst)
  | CExp_BinOp (op, lhs, rhs) ->
      let ctx, ol = lower_expr ctx lhs in
      let ctx, or_ = lower_expr ctx rhs in
      let binop_result_ty =
        match op with
        | CBinop_Comparison _ -> out_ty
        | _ -> arg_ty_of_operand ol
      in
      let ctx, dst = fresh_var ctx binop_result_ty in
      let rv : I.rvalue =
        {
          I.id = dst.I.id;
          node = I.CR_BinOp { op = binop_of_core op; lhs = ol; rhs = or_ };
          ty = binop_result_ty;
        }
      in
      let ctx, _ =
        emit ctx (I.CR_Assign { dst; rvalue = rv }) binop_result_ty
      in
      (ctx, I.CR_OVar dst)
  | CExp_Apply { closure_fun; args } -> (
      let ctx, arg_ops = List.fold_left_map lower_expr ctx args in
      (* Cast each arg operand to the concrete type knowned at apply site.
         The concrete type will be knowned before the calling site,
         which helps the monomorphization.*)
      let arg_tys = List.map (fun (a : C.expr) -> mk_ir_ty a.ty) args in
      let ctx, concrete_arg_ops =
        List.fold_left2
          (fun (ctx, acc) op arg_ty ->
            match op with
            | I.CR_OVar v
              when not (ir_type_equal v.I.ty.I.ir_type arg_ty.I.ir_type) ->
                let ctx, new_v = fresh_var ctx arg_ty in
                let ctx, _ = emit ctx (assign_cast_var new_v v arg_ty) arg_ty in
                (ctx, I.CR_OVar new_v :: acc)
            | I.CR_OVar _ | I.CR_OConstant _ -> (ctx, op :: acc))
          (ctx, []) arg_ops arg_tys
      in
      let concrete_arg_ops = List.rev concrete_arg_ops in
      match closure_fun.node with
      | CExp_Ident id -> (
          match StringMap.find_opt id.fullname ctx.toplevel_functions with
          | Some arity when List.length args = arity ->
              (* Known function, fully applied → direct call *)
              let ctx, call_dst, result =
                let ctx, dst = fresh_var ctx out_ty in
                (ctx, dst, I.CR_OVar dst)
              in
              let ctx, _ =
                emit ctx
                  (I.CR_Call
                     {
                       dst = call_dst;
                       target = I.Direct id.fullname;
                       args = concrete_arg_ops;
                     })
                  out_ty
              in
              (ctx, result)
          | Some _ ->
              (* Known function, partially applied → create closure *)
              let ctx, fn_var = fresh_var ctx out_ty in
              let ctx, _ =
                emit ctx
                  (I.CR_Make_closure
                     {
                       dst = fn_var;
                       fn = id.fullname;
                       free_vars =
                         []
                         (* the toplevel functions does not capture free vars
                          only refer to globals *);
                       captured_args = concrete_arg_ops;
                       initializer_fn = None;
                     })
                  out_ty
              in
              (ctx, I.CR_OVar fn_var)
          | None ->
              let ctx, closure = lower_expr ctx closure_fun in
              let closure_var : I.var =
                match closure with
                | I.CR_OVar v -> v
                | _ ->
                    failwith
                      "lowering: expected operand variable for closure apply"
              in
              lower_closure_apply ctx closure_var closure_fun.ty
                concrete_arg_ops out_ty)
      | _ ->
          let ctx, closure = lower_expr ctx closure_fun in
          let closure_var : I.var =
            match closure with
            | I.CR_OVar v -> v
            | _ ->
                failwith "lowering: expected operand variable for closure apply"
          in
          lower_closure_apply ctx closure_var closure_fun.ty concrete_arg_ops
            out_ty)
  | CExp_Let { rec_flag; name; value } -> (
      let lambda_name = name.fullname in
      match value.node with
      | CExp_Lambda lam ->
          (* Lift function, create closure *)
          let param_tys = get_args_ty value.ty in
          let ctx, fn_sir =
            lower_lambda_function ctx lambda_name lam param_tys value.id
          in
          let fn_sir = { fn_sir with I.visibility = I.CR_Private } in
          let ctx = { ctx with lifted_fns = fn_sir :: ctx.lifted_fns } in
          let ctx, fn_var = fresh_var_with_name ctx lambda_name out_ty in
          let free_var_idents =
            match Hashtbl.find_opt ctx.analysis.CA.closure_infos value.id with
            | Some info -> CA.VarIdSet.elements info.free_vars
            | None -> []
          in
          let free_vars =
            List.filter_map
              (fun (id : C.ident) -> StringMap.find_opt id.fullname ctx.env)
              free_var_idents
          in
          let make_closure =
            I.CR_Make_closure
              {
                dst = fn_var;
                fn = lambda_name;
                free_vars;
                captured_args = [];
                initializer_fn = None;
              }
          in
          let ctx, _ = emit ctx make_closure out_ty in
          let ctx =
            { ctx with env = StringMap.add name.fullname fn_var ctx.env }
          in
          (ctx, I.CR_OVar fn_var)
      | _ -> (
          (* Evaluate the value and always bind the let-name in the environment. *)
          let ctx, result = lower_expr ctx value in
          match result with
          | I.CR_OVar v ->
              let ctx =
                { ctx with env = StringMap.add name.fullname v ctx.env }
              in
              (ctx, I.CR_OVar v)
          | I.CR_OConstant _ ->
              let ctx, v = fresh_var_with_name ctx name.fullname out_ty in
              let rv : I.rvalue =
                {
                  I.id = v.I.id;
                  node = I.CR_Cast { src = result; to_ty = out_ty };
                  ty = out_ty;
                }
              in
              let ctx, _ =
                emit ctx (I.CR_Assign { dst = v; rvalue = rv }) out_ty
              in
              let ctx =
                { ctx with env = StringMap.add name.fullname v ctx.env }
              in
              (ctx, I.CR_OVar v)))
  | CExp_Seq xs ->
      List.fold_left (fun (ctx, _) x -> lower_expr ctx x) (ctx, void_null) xs
  | CExp_If { cond; then_branch; else_branch } ->
      let ctx, cond_op = lower_expr ctx cond in
      let ctx, cond_var =
        match cond_op with
        | I.CR_OVar v -> (ctx, v)
        | _ ->
            let ctx, v = fresh_var ctx (mk_ir_ty cond.ty) in
            let rv : I.rvalue =
              {
                I.id = v.I.id;
                node = I.CR_Cast { src = cond_op; to_ty = v.I.ty };
                ty = v.I.ty;
              }
            in
            let ctx, _ =
              emit ctx (I.CR_Assign { dst = v; rvalue = rv }) v.I.ty
            in
            (ctx, v)
      in
      let ctx, result_var = fresh_var ctx out_ty in
      let then_id = fresh_id () in
      let else_id = fresh_id () in
      let merge_id = fresh_id () in
      let ctx =
        finish_block ctx
          (I.CR_CondBr
             { cond = cond_var; then_block = then_id; else_block = else_id })
      in
      (* Thread then_id through pending_merge_id so a nested if's first
       finish_block uses then_id as its block ID, making it the CondBr target. *)
      let ctx = { ctx with pending_merge_id = Some then_id } in
      let ctx, then_result = lower_expr ctx then_branch in
      let then_rv : I.rvalue =
        {
          I.id = fresh_id ();
          node = I.CR_Move { src = then_result };
          ty = result_var.I.ty;
        }
      in
      let ctx, _ =
        emit ctx
          (I.CR_Assign { dst = result_var; rvalue = then_rv })
          result_var.I.ty
      in
      (* Create the merge block for a nested if, or the then block for a simple branch *)
      let ctx =
        if ctx.pending_merge_id = Some then_id then
          (* Simple branch: consume pending_merge_id to create the then block *)
          finish_block ctx (I.CR_Goto merge_id)
        else
          (* Nested if: its merge block gets the then result, then flows to outer merge *)
          finish_block ctx (I.CR_Goto merge_id)
      in
      let ctx, else_result =
        let ctx = { ctx with pending_merge_id = Some else_id } in
        match else_branch with
        | Some e ->
            let ctx, r = lower_expr ctx e in
            let else_rv : I.rvalue =
              {
                I.id = fresh_id ();
                node = I.CR_Move { src = r };
                ty = result_var.I.ty;
              }
            in
            let ctx, _ =
              emit ctx
                (I.CR_Assign { dst = result_var; rvalue = else_rv })
                result_var.I.ty
            in
            let ctx =
              if ctx.pending_merge_id = Some else_id then
                finish_block ctx (I.CR_Goto merge_id)
              else finish_block ctx (I.CR_Goto merge_id)
            in
            (ctx, r)
        | None -> (ctx, I.CR_OConstant (I.CR_Null, void_ir_ty))
      in
      let ctx = { ctx with pending_merge_id = Some merge_id } in
      (ctx, I.CR_OVar result_var)
  | CExp_Lambda lam ->
      let lambda_name = Printf.sprintf "__lambda_%d" (fresh_id ()) in
      let param_tys = get_args_ty e.ty in
      let ctx, fn_sir =
        lower_lambda_function ctx lambda_name lam param_tys e.id
      in
      let ctx = { ctx with lifted_fns = fn_sir :: ctx.lifted_fns } in
      let ctx, fn_var = fresh_var_with_name ctx lambda_name out_ty in
      let free_var_idents =
        match Hashtbl.find_opt ctx.analysis.CA.closure_infos e.id with
        | Some info -> CA.VarIdSet.elements info.free_vars
        | None -> []
      in
      let free_vars =
        List.filter_map
          (fun (id : C.ident) -> StringMap.find_opt id.fullname ctx.env)
          free_var_idents
      in
      let make_closure =
        I.CR_Make_closure
          {
            dst = fn_var;
            fn = lambda_name;
            free_vars;
            captured_args = [];
            initializer_fn = None;
          }
      in
      let ctx, _ = emit ctx make_closure out_ty in
      (ctx, I.CR_OVar fn_var)
  | CExp_Record fields ->
      let field_count = List.length fields in
      let field_types =
        List.map (fun (f : C.record_field) -> mk_ir_ty f.field_ty) fields
      in
      let ptr_ty : I.ty =
        { I.id = 0; I.ir_type = I.CR_Obj { named = None; args = [] } }
      in
      let ctx, obj_var = fresh_var ctx ptr_ty in
      let size_op : I.operand =
        I.CR_OConstant
          ( I.CR_IntLit (string_of_int field_count),
            { I.id = 0; I.ir_type = I.CR_I64 } )
      in
      let layout = I.CR_Record { field_count; field_types; tag_variant = 0 } in
      let ctx, _ =
        emit ctx
          (I.CR_Object_create
             { dst = obj_var; size = size_op; layout; initializer_fn = None })
          (mk_ir_ty e.ty)
      in
      let ctx =
        List.fold_left
          (fun ctx (f : C.record_field) ->
            let ctx, fval = lower_expr ctx f.field_value in
            let field_ty = mk_ir_ty f.field_ty in
            let idx_op : I.operand =
              I.CR_OConstant
                ( I.CR_IntLit (string_of_int f.field_idx),
                  { I.id = 0; I.ir_type = I.CR_I64 } )
            in
            let ctx, _ =
              emit ctx
                (I.CR_Object_set
                   {
                     obj = obj_var;
                     field_idx = idx_op;
                     value = fval;
                     value_ty = field_ty;
                   })
                field_ty
            in
            ctx)
          ctx fields
      in
      (ctx, I.CR_OVar obj_var)
  | CExp_Field { record; field_idx } ->
      let ctx, obj_op = lower_expr ctx record in
      let idx_op : I.operand =
        I.CR_OConstant
          ( I.CR_IntLit (string_of_int field_idx),
            { I.id = 0; I.ir_type = I.CR_I64 } )
      in
      let ctx, dst = fresh_var ctx out_ty in
      let rv : I.rvalue =
        {
          I.id = dst.I.id;
          node =
            I.CR_Object_get
              { obj = obj_op; field_idx = idx_op; value_ty = out_ty };
          ty = out_ty;
        }
      in
      let ctx, _ = emit ctx (I.CR_Assign { dst; rvalue = rv }) out_ty in
      (ctx, I.CR_OVar dst)
  | CExp_FieldSet { record; field_idx; value } ->
      let ctx, obj_op = lower_expr ctx record in
      let obj_var : I.var =
        match obj_op with
        | I.CR_OVar v -> v
        | _ -> raise (Lowering_error "FieldSet target must be a variable")
      in
      let ctx, val_op = lower_expr ctx value in
      let val_ty = mk_ir_ty value.ty in
      let idx_op : I.operand =
        I.CR_OConstant
          ( I.CR_IntLit (string_of_int field_idx),
            { I.id = 0; I.ir_type = I.CR_I64 } )
      in
      let ctx, _ =
        emit ctx
          (I.CR_Object_set
             {
               obj = obj_var;
               field_idx = idx_op;
               value = val_op;
               value_ty = val_ty;
             })
          val_ty
      in
      (ctx, void_null)
  | CExp_VariantConstructor _ | CExp_ArrayCreate _ | CExp_ArrayLength _
  | CExp_ArrayGet _ | CExp_ArraySet _ | CExp_Loop _ | CExp_Break _
  | CExp_Continue | CExp_Return _ | CExp_Switch _ | CExp_GetTagVariant _ ->
      raise (Lowering_error "core form not lowered to SIR yet")

and lower_lambda_function (ctx : ctx) (name : string) (lam : C.lambda)
    (param_tys : C.ty list) (lambda_expr_id : int) : ctx * I.function_cir =
  let param_tys =
    List.filter (fun ty -> ty.ty_desc <> CTy_Constant CTy_Unit) param_tys
  in
  let free_idents =
    match Hashtbl.find_opt ctx.analysis.CA.closure_infos lambda_expr_id with
    | Some info -> CA.VarIdSet.elements info.free_vars
    | None -> []
  in
  let free_vars : I.var list =
    List.filter_map (fun (id : C.ident) -> env_find_var_opt ctx id) free_idents
  in
  let lambda_body_ctx, lambda_param_vars =
    let base_ctx =
      {
        empty_ctx with
        env = ctx.env;
        toplevel_functions = ctx.toplevel_functions;
        analysis = ctx.analysis;
        tmp_counter = ref 0 (* reset __var_ counter for function body *);
        block_counter = ref 0;
      }
    in
    let ctx_with_free_vars =
      List.fold_left (fun ctx fv -> env_add_var ctx fv) base_ctx free_vars
    in
    let body_ctx, lambda_params =
      List.fold_left2
        (fun (ctx, vars) (p : C.ident) (pty : C.ty) ->
          let ir_pty : I.ty = mk_ir_ty pty in
          let ctx, v = fresh_var_with_name ctx p.fullname ir_pty in
          let ctx = env_add_var ctx v in
          (ctx, v :: vars))
        (ctx_with_free_vars, free_vars)
        lam.params param_tys
    in
    (body_ctx, List.rev lambda_params)
  in
  let body_ctx, ret_op = lower_expr lambda_body_ctx lam.body in
  let ctx = { ctx with lifted_fns = body_ctx.lifted_fns @ ctx.lifted_fns } in
  let declared_ret_ty = mk_ir_ty lam.ret_ty in
  let ret_term =
    if declared_ret_ty.I.ir_type = I.CR_Void then I.CR_Return None
    else I.CR_Return (Some ret_op)
  in
  let body_ctx = finish_block body_ctx ret_term in
  let blocks = List.rev body_ctx.blocks in
  let entry_block = List.hd blocks in
  let locals = List.rev body_ctx.locals in
  let fn_sir : I.function_cir =
    {
      I.id = fresh_id ();
      name;
      params = lambda_param_vars;
      locals;
      entry_block;
      blocks;
      return_ty = declared_ret_ty;
      visibility = I.CR_Public;
    }
  in
  (ctx, fn_sir)

let ffi_of_signature (s : C.signature_item) : I.ffi_external_function option =
  match s.signature_item_desc with
  | C.CSig_Fun { name; params; ret_ty; external_fn = Some ext } ->
      let params, ret_ty =
        match (params, ret_ty.ty_desc) with
        | [], CTy_Arrow (fn_params, fn_ret) -> (fn_params, fn_ret)
        | _ -> (params, ret_ty)
      in
      Some
        {
          I.name = ext.c_name;
          syli_name = name.fullname;
          ret_ty = mk_ir_ty ret_ty;
          params = List.map mk_ir_ty params;
          calling_convention = ext.calling_convention;
        }
  | _ -> None

let build_const_init_fn (name : string) (value : I.constant) (ty : I.ty) :
    I.function_cir =
  let block_id = fresh_id () in
  let term_id = fresh_id () in
  let void_ty : I.ty = { I.id = 0; I.ir_type = I.CR_Void } in
  let void_var : I.var =
    let id = fresh_id () in
    { I.id; I.name = "__void_" ^ string_of_int id; I.ty = void_ty }
  in
  let ret_op = I.CR_OConstant (value, ty) in
  let term : I.terminator =
    { I.id = term_id; node = I.CR_Return (Some ret_op) }
  in
  let entry_block : I.block =
    {
      I.id = block_id;
      label_id = 0;
      statements = [];
      terminator = term;
      pred_blocks = [];
      succ_blocks = [];
    }
  in
  {
    I.id = fresh_id ();
    name;
    params = [];
    locals = [ void_var ];
    entry_block;
    blocks = [ entry_block ];
    return_ty = ty;
    visibility = I.CR_Private;
  }

let build_module_initializer (module_name : string)
    (globals : I.global_value list) : I.function_cir =
  let void_ty : I.ty = { I.id = 0; I.ir_type = I.CR_Void } in
  let void_var : I.var =
    let id = fresh_id () in
    { I.id; I.name = "__void_" ^ string_of_int id; I.ty = void_ty }
  in
  let stmts_acc, locals_acc =
    List.fold_left
      (fun (stmts_acc, locals_acc) (index, (gv : I.global_value)) ->
        let tmp_var : I.var =
          {
            I.id = fresh_id ();
            I.name = "__init_tmp_" ^ string_of_int index;
            I.ty = gv.ty;
          }
        in
        let call_stmt : I.statement =
          {
            I.id = fresh_id ();
            node =
              I.CR_Call
                { dst = tmp_var; target = Direct gv.init_fn.name; args = [] };
            ty = gv.ty;
          }
        in
        let store_stmt : I.statement =
          {
            I.id = fresh_id ();
            node =
              I.CR_Store_global { global = gv.name; value = I.CR_OVar tmp_var };
            ty = gv.ty;
          }
        in
        (store_stmt :: call_stmt :: stmts_acc, tmp_var :: locals_acc))
      ([], [])
      (List.mapi (fun i gv -> (i, gv)) globals)
  in
  let stmts = List.rev stmts_acc in
  let locals = List.rev locals_acc in
  let term_id = fresh_id () in
  let term : I.terminator = { I.id = term_id; node = I.CR_Return None } in
  let block_id = fresh_id () in
  let entry_block : I.block =
    {
      I.id = block_id;
      label_id = 0;
      statements = stmts;
      terminator = term;
      pred_blocks = [];
      succ_blocks = [];
    }
  in
  {
    I.id = fresh_id ();
    name = "__init." ^ module_name;
    params = [];
    locals = void_var :: locals;
    entry_block;
    blocks = [ entry_block ];
    return_ty = void_ty;
    visibility = I.CR_Public;
  }

let lower_program (prog : C.program_core) : I.module_cir =
  let analysis = Syli_core.Closure_analysis.run prog in
  (* Add FFI functions to toplevel_functions *)
  let ffi_known_fns =
    List.fold_left
      (fun acc (s : C.signature_item) ->
        match s.signature_item_desc with
        | C.CSig_Fun { name; params; ret_ty; external_fn = Some _ } ->
            let arity =
              match (params, ret_ty.ty_desc) with
              | [], CTy_Arrow (fn_params, _) -> List.length fn_params
              | _ -> List.length params
            in
            StringMap.add name.fullname arity acc
        | _ -> acc)
      StringMap.empty prog.signature_items
  in
  let toplevel_functions =
    let base = collect_toplevel_functions prog in
    StringMap.union (fun _ v _ -> Some v) base ffi_known_fns
  in
  let root_ctx, functions, globals =
    List.fold_left
      (fun (ctx, fns, globs) (item : C.structure_item) ->
        match item.structure_item_desc with
        | CStr_Let { name; value; _ } -> (
            match value.node with
            | CExp_Lambda lam ->
                let param_tys = get_args_ty value.ty in
                let ctx, fn =
                  lower_lambda_function ctx name.fullname lam param_tys value.id
                in
                let fn_ty = mk_ir_ty value.ty in
                let fn_var : I.var =
                  { I.id = fresh_id (); I.name = name.fullname; I.ty = fn_ty }
                in
                let ctx =
                  { ctx with env = StringMap.add fn_var.name fn_var ctx.env }
                in
                (ctx, fn :: fns, globs)
            | CExp_Constant c ->
                let const_value = ir_const_of_core c in
                let const_ty = mk_ir_ty value.ty in
                let init_fn_name = "__init_global." ^ name.fullname in
                let init_fn =
                  build_const_init_fn init_fn_name const_value const_ty
                in
                let gv : I.global_value =
                  {
                    I.name = name.fullname;
                    init_fn;
                    value = const_value;
                    ty = const_ty;
                    visibility = I.CR_Public;
                  }
                in
                let const_var : I.var =
                  {
                    I.id = fresh_id ();
                    I.name = name.fullname;
                    I.ty = const_ty;
                  }
                in
                let ctx =
                  {
                    ctx with
                    env = StringMap.add name.fullname const_var ctx.env;
                  }
                in
                (ctx, init_fn :: fns, gv :: globs)
            | _ ->
                (* Non-constant, non-lambda:
                   create a global with CR_Null and an init function that computes
                   the value and returns it.
                   The module initializer function will call the init
                   function and store the result to the global. *)
                let global_ty = mk_ir_ty value.ty in
                let value_ctx =
                  {
                    empty_ctx with
                    env = ctx.env;
                    toplevel_functions;
                    analysis;
                    tmp_counter = ref 0;
                    block_counter = ref 0;
                  }
                in
                let value_ctx, result = lower_expr value_ctx value in
                let value_ctx =
                  finish_block value_ctx (I.CR_Return (Some result))
                in
                let init_fn_name = "__init_global." ^ name.fullname in
                let blocks = List.rev value_ctx.blocks in
                let entry_block = List.hd blocks in
                let init_fn : I.function_cir =
                  {
                    I.id = fresh_id ();
                    name = init_fn_name;
                    params = [];
                    locals = List.rev value_ctx.locals;
                    entry_block;
                    blocks;
                    return_ty = global_ty;
                    visibility = I.CR_Private;
                  }
                in
                let gv : I.global_value =
                  {
                    I.name = name.fullname;
                    init_fn;
                    value = I.CR_Null;
                    ty = global_ty;
                    visibility = I.CR_Public;
                  }
                in
                let global_var : I.var =
                  {
                    I.id = fresh_id ();
                    I.name = name.fullname;
                    I.ty = global_ty;
                  }
                in
                let ctx =
                  {
                    ctx with
                    env = StringMap.add name.fullname global_var ctx.env;
                  }
                in
                (ctx, init_fn :: fns, gv :: globs))
        | CStr_TypeDef _ -> (ctx, fns, globs))
      ({ empty_ctx with toplevel_functions; analysis }, [], [])
      prog.C.structure_items
  in
  let ffi_external_functions =
    prog.signature_items |> List.filter_map ffi_of_signature
  in
  let global_values = List.rev globals in
  let module_init_fn =
    build_module_initializer prog.C.name.fullname global_values
  in
  let functions =
    module_init_fn :: List.rev (root_ctx.lifted_fns @ List.rev functions)
  in
  {
    I.name = prog.C.name.fullname;
    type_defs = [];
    functions;
    global_values;
    ffi_external_functions;
  }

let lower (ctx : Pipeline_types.core_ctx) : Pipeline_types.cir_ctx =
  { Pipeline_types.module_cir = lower_program ctx.Pipeline_types.program }

let run prog = lower_program prog
