open Syli_ir.Rir
open Llvm_lir
open Llvm_lir.Types
module Rir = Syli_ir.Rir
open Syli_common

exception Lowering_error of string

let fail (msg : string) : 'a = raise (Lowering_error msg)
let label_of_block_id (id : int) : string = "bb" ^ string_of_int id
let is_float_ir_type = function RR_Float | RR_Double -> true | _ -> false

let rec lltype_of_ir_type (ty : Rir.ir_type) : lltype =
  match ty with
  | RR_Bool -> LV_I1
  | RR_I64 | RR_U64 -> LV_I64
  | RR_I32 | RR_U32 -> LV_I32
  | RR_I16 | RR_U16 -> LV_I16
  | RR_I8 | RR_U8 -> LV_I8
  | RR_Float -> LV_Float
  | RR_Double -> LV_Double
  | RR_Void -> LV_Void
  | RR_Obj_Ptr _ -> LV_Ptr
  | RR_FnPtr -> LV_Ptr
  | RR_Str -> LV_Struct [ LV_Ptr; LV_I64 ]
  | RR_Arrow (args, ret) ->
      LV_Func (List.map lltype_of_ir_type args, lltype_of_ir_type ret)

let lltype_of_ty (t : Rir.ty) : lltype = lltype_of_ir_type t.ty

let parse_int64 (s : string) : int64 =
  let normalized = String.trim s in
  match Int64.of_string_opt normalized with Some v -> v | None -> 0L

let parse_float (s : string) : float =
  let normalized = String.trim s in
  match float_of_string_opt normalized with Some v -> v | None -> 0.0

let bool_of_string (s : string) : bool =
  match String.lowercase_ascii (String.trim s) with
  | "1" | "true" -> true
  | "0" | "false" -> false
  | _ -> failwith ("invalid bool string:" ^ s)

let var_name (v : Rir.var) : string = v.fullname

let llconst_of_ir_constant (c : Rir.constant) (ty : Rir.ty) : operand =
  let llty = lltype_of_ty ty in
  match c with
  | RR_IntLit s -> LV_Constant (LV_Integer (parse_int64 s), llty)
  | RR_FloatLit s -> (
      match llty with
      | LV_Float -> LV_Constant (LV_Float (parse_float s), llty)
      | LV_Double -> LV_Constant (LV_Double (parse_float s), llty)
      | _ ->
          raise
            (Failure "Float literal constant must have float or double type"))
  | RR_BoolLit s ->
      LV_Constant (LV_Integer (if bool_of_string s then 1L else 0L), LV_I1)
  | RR_StringLit _ ->
      failwith "RR_StringLit should not reach llconst_of_ir_constant"
  | RR_CharLit s ->
      let code = if s = "" then 0 else Char.code s.[0] in
      LV_Constant (LV_Integer (Int64.of_int code), llty)
  | RR_Null -> null llty

type lower_ctx = {
  var_env : operand IntMap.t;
  runtime_decls : lltype StringMap.t;
  functions : Rir.function_rir StringMap.t;
  ffi_functions : Rir.ffi_external_function StringMap.t;
  known_globals : StringSet.t;
  next_reg : int;
  block_label_map : int IntMap.t;
  str_data : string StringMap.t;
  allocas : lltype StringMap.t;
  need_unreachable : bool;
}

let fresh_reg (ctx : lower_ctx) (ty : lltype) : lower_ctx * operand =
  let n = ctx.next_reg in
  ({ ctx with next_reg = n + 1 }, LV_Local ("Sy_tmp" ^ string_of_int n, ty))

let add_decl_if_missing (ctx : lower_ctx) (name : string) (ty : lltype) :
    lower_ctx =
  if StringMap.mem name ctx.runtime_decls then ctx
  else { ctx with runtime_decls = StringMap.add name ty ctx.runtime_decls }

let fresh_global_id =
  let counter = ref 0 in
  fun () ->
    incr counter;
    !counter

let str_ty = LV_Struct [ LV_Ptr; LV_I64 ]

let rec lower_operand (ctx : lower_ctx) (op : Rir.operand) :
    lower_ctx * operand * instruction list =
  match op with
  | RR_OConstant (RR_StringLit s, ty) when ty.ty = RR_Str ->
      let ctx, str_name =
        match StringMap.find_opt s ctx.str_data with
        | Some name -> (ctx, name)
        | None ->
            let name = "__str." ^ string_of_int (fresh_global_id ()) in
            ({ ctx with str_data = StringMap.add s name ctx.str_data }, name)
      in
      let global_op = LV_Global (str_name, LV_Array (String.length s, LV_I8)) in
      let ctx, gep_tmp = fresh_reg ctx LV_Ptr in
      let ctx, s1 = fresh_reg ctx str_ty in
      let ctx, s2 = fresh_reg ctx str_ty in
      let len = Int64.of_int (String.length s) in
      ( ctx,
        s2,
        [
          LV_Assign
            ( gep_tmp,
              LV_GEP
                {
                  base = global_op;
                  indices = [ LV_Constant (LV_Integer 0L, LV_I32) ];
                  result_ty = LV_I8;
                } );
          LV_Assign
            ( s1,
              LV_InsertValue
                {
                  agg = LV_Constant (LV_ZeroInitializer, str_ty);
                  value = gep_tmp;
                  index = 0;
                  ty = str_ty;
                } );
          LV_Assign
            ( s2,
              LV_InsertValue
                {
                  agg = s1;
                  value = LV_Constant (LV_Integer len, LV_I64);
                  index = 1;
                  ty = str_ty;
                } );
        ] )
  | RR_OConstant (c, ty) -> (ctx, llconst_of_ir_constant c ty, [])
  | RR_OVar v -> (
      let key = v.id in
      match IntMap.find_opt key ctx.var_env with
      | Some op' ->
          if StringMap.mem v.fullname ctx.allocas then
            let ctx, temp = fresh_reg ctx (lltype_of_ty v.ty) in
            ( ctx,
              temp,
              [
                LV_Assign (temp, LV_Load { ptr = op'; ty = lltype_of_ty v.ty });
              ] )
          else (ctx, op', [])
      | None ->
          if not (StringSet.mem v.fullname ctx.known_globals) then
            fail
              (Printf.sprintf
                 "Unbound RIR variable during RIR->LLVM lowering: id=%d name=%s"
                 v.id v.fullname);
          let load_ty = lltype_of_ty v.ty in
          let ctx, load_tmp = fresh_reg ctx load_ty in
          ( ctx,
            load_tmp,
            [
              LV_Assign
                ( load_tmp,
                  LV_Load { ptr = global v.fullname LV_Ptr; ty = load_ty } );
            ] ))

let lower_runtime_arg (ctx : lower_ctx) (arg : Rir.operand) :
    lower_ctx * operand * instruction list =
  lower_operand ctx arg

let call_rhs (ctx : lower_ctx) ~(fn_name : string) ~(ret_ty : lltype)
    ~(args : operand list) : lower_ctx * instr_rhs =
  let param_tys = List.map ty_of_operand args in
  let fn_ty = LV_Func (param_tys, ret_ty) in
  let ctx = add_decl_if_missing ctx fn_name fn_ty in
  (ctx, LV_Call { fn = global fn_name fn_ty; args; ret_ty })

let assign_rhs_to_var (ctx : lower_ctx) (dst : Rir.var) (rhs : instr_rhs) :
    lower_ctx * instruction list =
  let dst_op = LV_Local (var_name dst, lltype_of_ty dst.ty) in
  ( { ctx with var_env = IntMap.add dst.id dst_op ctx.var_env },
    [ LV_Assign (dst_op, rhs) ] )

let ensure_typed_slot_ptr (_ctx : lower_ctx) (ptr : operand)
    (_value_ty : Rir.ty) : instruction list * operand =
  ([], ptr)

let lower_object_slot_ptr (ctx : lower_ctx) (obj : Rir.operand)
    (field_idx : Rir.operand) (value_ty : Rir.ty) :
    lower_ctx * instruction list * operand =
  let ctx, obj', extra1 = lower_operand ctx obj in
  let ctx, idx', extra2 = lower_operand ctx field_idx in
  let object_ty = LV_Struct [ LV_I64; LV_I64; LV_Array (0, LV_I64) ] in
  let zero = LV_Constant (LV_Integer 0L, LV_I32) in
  let offset =
    LV_Constant (LV_Integer (Int64.of_int Rir.values_offset), LV_I32)
  in
  let slot_ptr_rhs =
    LV_GEP
      { base = obj'; indices = [ zero; offset; idx' ]; result_ty = object_ty }
  in
  let ctx, slot_reg = fresh_reg ctx LV_Ptr in
  (ctx, extra1 @ extra2 @ [ LV_Assign (slot_reg, slot_ptr_rhs) ], slot_reg)

type signedness_kind = Signed | Unsigned

let signedness_kind = function
  | RR_I32 | RR_I64 | RR_I16 | RR_I8 -> Signed
  | RR_U32 | RR_U64 | RR_U16 | RR_U8 -> Unsigned
  | _ -> fail "type does not have signedness"

type binop_kind = Cmp | FloatArith | IntArith

let binop_kind (op : Rir.binop) (ty : Rir.ir_type) : binop_kind =
  match op with
  | CR_Eq | CR_Ne | CR_Lt | CR_Le | CR_Gt | CR_Ge -> Cmp
  | _ -> if is_float_ir_type ty then FloatArith else IntArith

let lower_compare_integer (op : Rir.binop) (ty : Rir.ir_type) : icmp_cond =
  match op with
  | CR_Eq -> LV_IEq
  | CR_Ne -> LV_INe
  | _ -> (
      match (op, signedness_kind ty) with
      | CR_Lt, Signed -> LV_ISlt
      | CR_Lt, Unsigned -> LV_IUlt
      | CR_Le, Signed -> LV_ISle
      | CR_Le, Unsigned -> LV_IUle
      | CR_Gt, Signed -> LV_ISgt
      | CR_Gt, Unsigned -> LV_IUgt
      | CR_Ge, Signed -> LV_ISge
      | CR_Ge, Unsigned -> LV_IUge
      | _ -> failwith "unsuported operation")

let lower_integer_binop (op : Rir.binop) (ty : Rir.ir_type) : ibinop =
  match op with
  | CR_Add -> LV_IAdd
  | CR_Sub -> LV_ISub
  | CR_Mul -> LV_IMul
  | CR_Div when signedness_kind ty = Signed -> LV_ISDiv
  | CR_Div -> LV_IUDiv
  | CR_Mod when signedness_kind ty = Signed -> LV_ISRem
  | CR_Mod -> LV_IURem
  | CR_BitAnd -> LV_IBitAnd
  | CR_BitOr | CR_Or -> LV_IBitOr
  | CR_BitXor -> LV_IBitXor
  | CR_Shl -> LV_IShl
  | CR_Shr -> LV_IAShr
  | CR_And -> LV_IBitAnd
  | _ -> fail "unsupported integer binary operator"

let lower_float_binop (op : Rir.binop) : fbinop =
  match op with
  | CR_Add -> LV_FAdd
  | CR_Sub -> LV_FSub
  | CR_Mul -> LV_FMul
  | CR_Div -> LV_FDiv
  | CR_Mod -> LV_FRem
  | _ -> fail "unsupported float binary operator"

let lower_target_operand (ctx : lower_ctx) (target : Rir.call_target)
    (args : operand list) (ret_ty : lltype) :
    lower_ctx * operand * instruction list =
  let arg_tys = List.map ty_of_operand args in
  match target with
  | Direct name -> (
      match StringMap.find_opt name ctx.functions with
      | Some (fn : Rir.function_rir) ->
          let params =
            List.map (fun (v : Rir.var) -> lltype_of_ty v.ty) fn.params
          in
          let fn_ty = LV_Func (params, lltype_of_ty fn.return_ty) in
          (ctx, global name fn_ty, [])
      | None -> (
          match StringMap.find_opt name ctx.ffi_functions with
          | Some ffi ->
              let params = List.map lltype_of_ty ffi.params in
              let fn_ty = LV_Func (params, lltype_of_ty ffi.ret_ty) in
              (ctx, global ffi.name fn_ty, [])
          | None -> (ctx, global name (LV_Func (arg_tys, ret_ty)), [])))
  | Indirect v -> (
      let ctx, op, extra = lower_operand ctx (RR_OVar v) in
      match ty_of_operand op with
      | LV_Func _ -> (ctx, op, extra)
      | LV_Ptr -> (ctx, op, extra)
      | _ ->
          raise
            (Failure
               (Printf.sprintf
                  "Indirect call operand does not have function type: %s has \
                   type %s"
                  (var_name v)
                  (string_of_lltype (ty_of_operand op)))))

let lower_rvalue_rhs (ctx : lower_ctx) (rv : Rir.rvalue) :
    lower_ctx * instr_rhs * instruction list =
  match rv.node with
  | Rir.RR_BinOp { op; lhs; rhs } -> (
      let ctx, lhs', extra1 = lower_operand ctx lhs in
      let ctx, rhs', extra2 = lower_operand ctx rhs in
      match binop_kind op rv.ty.ty with
      | Cmp ->
          let operand_ty =
            match lhs with
            | RR_OConstant (_, ty) -> ty.ty
            | RR_OVar v -> v.ty.ty
          in
          ( ctx,
            LV_ICmp (lower_compare_integer op operand_ty, lhs', rhs'),
            extra1 @ extra2 )
      | FloatArith ->
          (ctx, LV_FBinOp (lower_float_binop op, lhs', rhs'), extra1 @ extra2)
      | IntArith ->
          ( ctx,
            LV_IBinOp (lower_integer_binop op rv.ty.ty, lhs', rhs'),
            extra1 @ extra2 ))
  | Rir.RR_UnOp { op; operand } -> (
      let ctx, value, extra = lower_operand ctx operand in
      let value_ty = ty_of_operand value in
      match op with
      | CR_Neg ->
          if is_float_ir_type rv.ty.ty then
            ( ctx,
              LV_FBinOp (LV_FSub, LV_Constant (LV_Float 0.0, value_ty), value),
              extra )
          else
            ( ctx,
              LV_IBinOp (LV_ISub, LV_Constant (LV_Integer 0L, value_ty), value),
              extra )
      | CR_Not -> (ctx, LV_IBinOp (LV_IBitXor, value, i1 true), extra)
      | CR_BitNot ->
          ( ctx,
            LV_IBinOp
              (LV_IBitXor, value, LV_Constant (LV_Integer (-1L), value_ty)),
            extra ))
  | Rir.RR_Runtime_call { fn_name; args; ret_ty } ->
      let ctx, args_results =
        List.fold_left_map
          (fun ctx a ->
            let ctx, o, e = lower_runtime_arg ctx a in
            (ctx, (o, e)))
          ctx args
      in
      let args_ops, extra_list = List.split args_results in
      let extra = List.concat extra_list in
      let ret_ty =
        match ret_ty with Some ty -> lltype_of_ty ty | None -> LV_Void
      in
      let fn_name = Rir.runtime_op_name_to_string fn_name in
      let ctx, rhs = call_rhs ctx ~fn_name ~ret_ty ~args:args_ops in
      (ctx, rhs, extra)
  | Rir.RR_Object_load _ ->
      fail "RR_Object_load must be lowered through lower_statement"
  | Rir.RR_Cast { src; to_ty } ->
      let ctx, src', extra = lower_operand ctx src in
      (ctx, LV_Cast (LV_BitCast, src', lltype_of_ty to_ty), extra)
  | Rir.RR_Addr_fn { fn } ->
      let fn_ptr = global fn LV_Ptr in
      let ptr_ty = lltype_of_ty rv.ty in
      (ctx, LV_Cast (LV_BitCast, fn_ptr, ptr_ty), [])

let lower_statement (ctx : lower_ctx) (stmt : Rir.statement) :
    lower_ctx * instruction list list =
  match stmt.node with
  | Rir.RR_Assign { dst; rvalue = { node = Rir.RR_Cast { src; to_ty }; _ } } ->
      let ctx, src', extra = lower_operand ctx src in
      if ty_of_operand src' = lltype_of_ty to_ty then
        ({ ctx with var_env = IntMap.add dst.id src' ctx.var_env }, [ extra ])
      else
        let ctx, instrs =
          assign_rhs_to_var ctx dst
            (LV_Cast (LV_BitCast, src', lltype_of_ty to_ty))
        in
        (ctx, [ extra; instrs ])
  | Rir.RR_Assign
      {
        dst;
        rvalue = { node = Rir.RR_Object_load { obj; field_idx; value_ty }; _ };
      } ->
      let ctx, ptr_instrs, typed_ptr =
        lower_object_slot_ptr ctx obj field_idx value_ty
      in
      let ctx, instrs =
        assign_rhs_to_var ctx dst
          (LV_Load { ptr = typed_ptr; ty = lltype_of_ty value_ty })
      in
      (ctx, [ ptr_instrs; instrs ])
  | Rir.RR_Assign { dst; rvalue } ->
      let ctx, rhs, extra = lower_rvalue_rhs ctx rvalue in
      let ctx, instrs = assign_rhs_to_var ctx dst rhs in
      (ctx, [ extra; instrs ])
  | Rir.RR_Call { dst; target; args } ->
      let ctx, args_results =
        List.fold_left_map
          (fun ctx a ->
            let ctx, o, e = lower_operand ctx a in
            (ctx, (o, e)))
          ctx args
      in
      let args_ops, extra_list = List.split args_results in
      let extra = List.concat extra_list in
      let ret_ty = lltype_of_ty dst.ty in
      let ctx, fn_op, extra2 =
        lower_target_operand ctx target args_ops ret_ty
      in
      let rhs = LV_Call { fn = fn_op; args = args_ops; ret_ty } in
      let ctx, instrs = assign_rhs_to_var ctx dst rhs in
      (ctx, [ extra; extra2; instrs ])
  | Rir.RR_Runtime_call { dst; call = { fn_name; args; ret_ty = _ } } ->
      let ctx, args_results =
        List.fold_left_map
          (fun ctx a ->
            let ctx, o, e = lower_runtime_arg ctx a in
            (ctx, (o, e)))
          ctx args
      in
      let args_ops, extra_list = List.split args_results in
      let extra = List.concat extra_list in
      let ret_ty = lltype_of_ty dst.ty in
      let fn_name = Rir.runtime_op_name_to_string fn_name in
      let ctx, rhs = call_rhs ctx ~fn_name ~ret_ty ~args:args_ops in
      let ctx, instrs = assign_rhs_to_var ctx dst rhs in
      (ctx, [ extra; instrs ])
  | Rir.RR_Object_store { obj; field_idx; value; value_ty } ->
      let ctx, ptr_instrs, typed_ptr =
        lower_object_slot_ptr ctx obj field_idx value_ty
      in
      let ctx, value_ops, extra = lower_operand ctx value in
      (ctx, [ ptr_instrs; extra; [ LV_Store (value_ops, typed_ptr) ] ])
  | Rir.RR_Move { dst; src } ->
      let val_ty = lltype_of_ty dst.ty in
      let ptr_op = LV_Local (var_name dst, LV_Ptr) in
      let ctx =
        {
          ctx with
          var_env = IntMap.add dst.id ptr_op ctx.var_env;
          allocas =
            (if StringMap.mem (var_name dst) ctx.allocas then ctx.allocas
             else StringMap.add (var_name dst) val_ty ctx.allocas);
        }
      in
      let ctx, src_ops, extra = lower_operand ctx src in
      (ctx, [ extra; [ LV_Store (src_ops, ptr_op) ] ])
  | Rir.RR_Store_global { global = global_name; value } ->
      let ctx, gv, extra = lower_operand ctx value in
      (ctx, [ extra; [ LV_Store (gv, global global_name LV_Ptr) ] ])
  | Rir.RR_Nop -> (ctx, [ [ LV_Comment "nop" ] ])

let lower_terminator (ctx : lower_ctx) (term : Rir.terminator) :
    lower_ctx * terminator * instruction list =
  match term.node with
  | RR_Goto id ->
      let label_id = IntMap.find id ctx.block_label_map in
      (ctx, LV_Br (label_of_block_id label_id), [])
  | RR_CondBr { cond; then_block; else_block } ->
      let then_label_id = IntMap.find then_block ctx.block_label_map in
      let else_label_id = IntMap.find else_block ctx.block_label_map in
      let ctx, cond_op, extra = lower_operand ctx (RR_OVar cond) in
      ( ctx,
        LV_CondBr
          ( cond_op,
            label_of_block_id then_label_id,
            label_of_block_id else_label_id ),
        extra )
  | RR_Switch { scrutinee; cases; default_block } ->
      let ctx, scrutinee_op, extra = lower_operand ctx (RR_OVar scrutinee) in
      let default_label, ctx =
        match default_block with
        | Some id ->
            (label_of_block_id (IntMap.find id ctx.block_label_map), ctx)
        | None ->
            ("switch_default_unreachable", { ctx with need_unreachable = true })
      in
      let cases' =
        List.map
          (fun (c : switch_case_node) ->
            ( LV_Constant (LV_Integer (Int64.of_int c.value), LV_I64),
              label_of_block_id (IntMap.find c.target_block ctx.block_label_map)
            ))
          cases
      in
      (ctx, LV_Switch (scrutinee_op, default_label, cases'), extra)
  | RR_Return value_opt -> (
      match value_opt with
      | None -> (ctx, LV_Ret None, [])
      | Some op ->
          let ctx, op', extra = lower_operand ctx op in
          (ctx, LV_Ret (Some op'), extra))

let lower_function (ctx : lower_ctx) (fn : Rir.function_rir) : lower_ctx * func
    =
  let ctx =
    List.fold_left
      (fun ctx (v : Rir.var) ->
        let name = var_name v in
        let llty = lltype_of_ty v.ty in
        { ctx with var_env = IntMap.add v.id (local name llty) ctx.var_env })
      ctx fn.params
  in
  let ctx =
    List.fold_left
      (fun ctx (v : Rir.var) ->
        if IntMap.mem v.id ctx.var_env then ctx
        else
          {
            ctx with
            var_env =
              IntMap.add v.id
                (local (var_name v) (lltype_of_ty v.ty))
                ctx.var_env;
          })
      ctx fn.locals
  in
  let final_ctx, blocks =
    fn.blocks
    |> List.fold_left_map
         (fun ctx (b : Rir.block) ->
           let ctx, stmt_instrs =
             List.fold_left
               (fun (ctx, acc) stmt ->
                 let ctx, instrs = lower_statement ctx stmt in
                 (ctx, instrs :: acc))
               (ctx, []) b.statements
           in
           let ctx, term, extra = lower_terminator ctx b.terminator in
           ( ctx,
             {
               label = label_of_block_id b.label_id;
               instructions =
                 List.flatten (List.flatten (List.rev stmt_instrs)) @ extra;
               terminator = term;
             } ))
         ctx
    |> fun (final_ctx, blocks) ->
    let blocks =
      let alloca_instrs =
        StringMap.fold
          (fun name ty acc ->
            LV_Assign (LV_Local (name, LV_Ptr), LV_Alloca ty) :: acc)
          final_ctx.allocas []
      in
      let blocks =
        if final_ctx.need_unreachable then
          blocks
          @ [
              {
                label = "switch_default_unreachable";
                instructions = [];
                terminator = LV_Unreachable;
              };
            ]
        else blocks
      in
      match blocks with
      | entry :: rest ->
          { entry with instructions = alloca_instrs @ entry.instructions }
          :: rest
      | [] -> []
    in
    (final_ctx, blocks)
  in
  let params =
    List.map (fun (v : Rir.var) -> (lltype_of_ty v.ty, var_name v)) fn.params
  in
  ( final_ctx,
    {
      name = fn.name;
      ret_type = lltype_of_ty fn.return_ty;
      params;
      blocks;
      linkage =
        (match fn.visibility with
        | CR_Public -> External
        | CR_Private -> Private);
    } )

let lower_global (g : Rir.global_value) : global_var =
  let g_type = lltype_of_ty g.ty in
  let g_init =
    match g.value with
    | RR_IntLit s -> Some (LV_Integer (parse_int64 s))
    | RR_FloatLit s ->
        Some
          (match g_type with
          | LV_Float -> LV_Float (parse_float s)
          | LV_Double -> LV_Double (parse_float s)
          | _ -> LV_Double (parse_float s))
    | RR_BoolLit s -> Some (LV_Integer (if bool_of_string s then 1L else 0L))
    | RR_CharLit s ->
        let code = if s = "" then 0 else Char.code s.[0] in
        Some (LV_Integer (Int64.of_int code))
    | RR_StringLit _ -> None
    | RR_Null -> (
        match g_type with
        | LV_Ptr | LV_Named _ | LV_Struct _ | LV_Array _ -> Some LV_Null
        | _ -> Some LV_ZeroInitializer)
  in
  {
    g_name = g.name;
    g_type;
    g_init;
    g_linkage =
      (match g.visibility with CR_Public -> External | CR_Private -> Private);
  }

let lower_program (prog : Rir.program_rir) : module_ =
  let final_ctx, functions =
    List.fold_left_map
      (fun ctx (fn : Rir.function_rir) ->
        let block_label_map =
          List.fold_left
            (fun map (b : Rir.block) -> IntMap.add b.id b.label_id map)
            IntMap.empty
            (fn.entry_block :: fn.blocks)
        in
        let fn_ctx =
          {
            ctx with
            var_env = IntMap.empty;
            next_reg = 0;
            block_label_map;
            allocas = StringMap.empty;
            need_unreachable = false;
          }
        in
        let fn_ctx_after, fn_result = lower_function fn_ctx fn in
        ( {
            ctx with
            runtime_decls = fn_ctx_after.runtime_decls;
            str_data = fn_ctx_after.str_data;
          },
          fn_result ))
      {
        var_env = IntMap.empty;
        runtime_decls = StringMap.empty;
        functions =
          List.fold_left
            (fun map (fn : Rir.function_rir) -> StringMap.add fn.name fn map)
            StringMap.empty prog.functions;
        ffi_functions =
          List.fold_left
            (fun map (ffi : Rir.ffi_external_function) ->
              StringMap.add ffi.syli_name ffi map)
            StringMap.empty prog.ffi_external_functions;
        known_globals =
          List.fold_left
            (fun set (gv : Rir.global_value) -> StringSet.add gv.name set)
            StringSet.empty prog.global_values;
        next_reg = 0;
        block_label_map = IntMap.empty;
        str_data = StringMap.empty;
        allocas = StringMap.empty;
        need_unreachable = false;
      }
      prog.functions
  in
  let runtime_declarations =
    StringMap.fold
      (fun name ty acc -> (name, ty) :: acc)
      final_ctx.runtime_decls []
    |> List.sort compare
  in
  let ffi_declarations =
    List.map
      (fun (ffi : Rir.ffi_external_function) ->
        let params = List.map lltype_of_ty ffi.params in
        (ffi.name, LV_Func (params, lltype_of_ty ffi.ret_ty)))
      prog.ffi_external_functions
  in
  let declarations = runtime_declarations @ ffi_declarations in
  let globals =
    let str_globals =
      StringMap.fold
        (fun s name acc ->
          {
            g_name = name;
            g_type = LV_Array (String.length s, LV_I8);
            g_init = Some (LV_StringLit s);
            g_linkage = Private;
          }
          :: acc)
        final_ctx.str_data []
    in
    List.map lower_global prog.global_values @ str_globals
  in
  let type_defs =
    List.map (fun (name, ty) -> (name, lltype_of_ty ty)) prog.type_defs
  in
  {
    target_triple = None;
    type_defs;
    declarations;
    globals;
    functions;
    source_filename = prog.name;
  }

let to_string (prog : Rir.program_rir) : string =
  module_to_string (lower_program prog)
