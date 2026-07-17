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
  | RR_Char -> LV_I8
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
  | _ -> false

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

type fn_sig = { params : lltype list; ret : lltype }

type lower_ctx = {
  var_env : (int, operand) Hashtbl.t;
  runtime_decls : (string, lltype) Hashtbl.t;
  fn_sigs : (string, fn_sig) Hashtbl.t;
  ffi_syli_names : (string, string) Hashtbl.t;
  known_globals : StringSet.t;
  next_reg : int ref;
  block_label_map : (int, int) Hashtbl.t;
  str_data : (string, string) Hashtbl.t;
}

let fresh_reg (ctx : lower_ctx) (ty : lltype) : operand =
  let n = !(ctx.next_reg) in
  ctx.next_reg := n + 1;
  LV_Local ("Sy_tmp" ^ string_of_int n, ty)

let add_decl_if_missing (ctx : lower_ctx) (name : string) (ty : lltype) : unit =
  if not (Hashtbl.mem ctx.runtime_decls name) then
    Hashtbl.add ctx.runtime_decls name ty

let fresh_global_id = Syli_ir.Cir.fresh_id
let str_ty = LV_Struct [ LV_Ptr; LV_I64 ]

let rec lower_operand (ctx : lower_ctx) (alloca_set : StringSet.t)
    (op : Rir.operand) : operand * instruction list * StringSet.t =
  match op with
  | RR_OConstant (RR_StringLit s, ty) when ty.ty = RR_Str ->
      let str_name =
        match Hashtbl.find_opt ctx.str_data s with
        | Some name -> name
        | None ->
            let name = "__str." ^ string_of_int (fresh_global_id ()) in
            Hashtbl.replace ctx.str_data s name;
            name
      in
      let global_op = LV_Global (str_name, LV_Array (String.length s, LV_I8)) in
      let gep_tmp = fresh_reg ctx LV_Ptr in
      let s1 = fresh_reg ctx str_ty in
      let s2 = fresh_reg ctx str_ty in
      let len = Int64.of_int (String.length s) in
      ( s2,
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
        ],
        alloca_set )
  | RR_OConstant (c, ty) -> (llconst_of_ir_constant c ty, [], alloca_set)
  | RR_OVar v -> (
      let key = v.id in
      match Hashtbl.find_opt ctx.var_env key with
      | Some op' ->
          if StringSet.mem v.fullname alloca_set then
            let temp = fresh_reg ctx (lltype_of_ty v.ty) in
            ( temp,
              [
                LV_Assign (temp, LV_Load { ptr = op'; ty = lltype_of_ty v.ty });
              ],
              alloca_set )
          else (op', [], alloca_set)
      | None ->
          if not (StringSet.mem v.fullname ctx.known_globals) then
            fail
              (Printf.sprintf
                 "Unbound RIR variable during RIR->LLVM lowering: id=%d name=%s"
                 v.id v.fullname);
          let load_ty = lltype_of_ty v.ty in
          let load_tmp = fresh_reg ctx load_ty in
          ( load_tmp,
            [
              LV_Assign
                ( load_tmp,
                  LV_Load { ptr = global v.fullname LV_Ptr; ty = load_ty } );
            ],
            alloca_set ))

let lower_runtime_arg (ctx : lower_ctx) (alloca_set : StringSet.t)
    (arg : Rir.operand) : operand * instruction list * StringSet.t =
  lower_operand ctx alloca_set arg

let call_rhs (ctx : lower_ctx) ~(fn_name : string) ~(ret_ty : lltype)
    ~(args : operand list) : instr_rhs =
  let param_tys = List.map ty_of_operand args in
  let fn_ty = LV_Func (param_tys, ret_ty) in
  add_decl_if_missing ctx fn_name fn_ty;
  LV_Call { fn = global fn_name fn_ty; args; ret_ty }

let assign_rhs_to_var (ctx : lower_ctx) (dst : Rir.var) (rhs : instr_rhs) :
    instruction list =
  let dst_op = LV_Local (var_name dst, lltype_of_ty dst.ty) in
  Hashtbl.replace ctx.var_env dst.id dst_op;
  [ LV_Assign (dst_op, rhs) ]

let ensure_typed_slot_ptr (_ctx : lower_ctx) (ptr : operand)
    (_value_ty : Rir.ty) : instruction list * operand =
  ([], ptr)

let lower_object_slot_ptr (ctx : lower_ctx) (alloca_set : StringSet.t)
    (obj : Rir.operand) (field_idx : Rir.operand) (value_ty : Rir.ty) :
    instruction list * operand * StringSet.t =
  let obj', extra1, alloca_set = lower_operand ctx alloca_set obj in
  let idx', extra2, alloca_set = lower_operand ctx alloca_set field_idx in
  let values_ptr_rhs =
    LV_GEP
      {
        base = obj';
        indices =
          [
            llconst_of_ir_constant
              (RR_IntLit (string_of_int Rir.values_offset))
              { id = fresh_global_id (); ty = RR_I32 };
          ];
        result_ty = LV_I64;
      }
  in
  let values_ptr_reg = fresh_reg ctx LV_Ptr in
  let slot_ptr_rhs =
    LV_GEP { base = values_ptr_reg; indices = [ idx' ]; result_ty = LV_I64 }
  in
  let slot_reg = fresh_reg ctx LV_Ptr in
  ( extra1 @ extra2
    @ [
        LV_Assign (values_ptr_reg, values_ptr_rhs);
        LV_Assign (slot_reg, slot_ptr_rhs);
      ],
    slot_reg,
    alloca_set )

let is_signed = function
  | RR_I32 | RR_I64 | RR_I16 | RR_I8 -> true
  | RR_U32 | RR_U64 | RR_U16 | RR_U8 -> false
  | _ -> fail "type does not have signedness"

let lower_compare_integer (op : Rir.binop) (ty : Rir.ir_type) : icmp_cond =
  match op with
  | CR_Eq -> LV_IEq
  | CR_Ne -> LV_INe
  | _ -> (
      if is_signed ty then
        match op with
        | CR_Lt -> LV_ISlt
        | CR_Le -> LV_ISle
        | CR_Gt -> LV_ISgt
        | CR_Ge -> LV_ISge
        | _ -> fail "not a comparison operator"
      else
        match op with
        | CR_Lt -> LV_IUlt
        | CR_Le -> LV_IUle
        | CR_Gt -> LV_IUgt
        | CR_Ge -> LV_IUge
        | _ -> fail "not a comparison operator")

let lower_integer_binop (op : Rir.binop) (ty : Rir.ir_type) : ibinop =
  match op with
  | CR_Add -> LV_IAdd
  | CR_Sub -> LV_ISub
  | CR_Mul -> LV_IMul
  | CR_Div when is_signed ty -> LV_ISDiv
  | CR_Div -> LV_IUDiv
  | CR_Mod when is_signed ty -> LV_ISRem
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

let lower_target_operand (ctx : lower_ctx) (alloca_set : StringSet.t)
    (target : Rir.call_target) (args : operand list) (ret_ty : lltype) :
    operand * instruction list * StringSet.t =
  let arg_tys = List.map ty_of_operand args in
  match target with
  | Direct name ->
      let c_name =
        match Hashtbl.find_opt ctx.ffi_syli_names name with
        | Some c -> c
        | None -> name
      in
      let fn_ty =
        match Hashtbl.find_opt ctx.fn_sigs c_name with
        | Some s -> LV_Func (s.params, s.ret)
        | None -> LV_Func (arg_tys, ret_ty)
      in
      (global c_name fn_ty, [], alloca_set)
  | Indirect v -> (
      let op, extra, alloca_set = lower_operand ctx alloca_set (RR_OVar v) in
      match ty_of_operand op with
      | LV_Func _ -> (op, extra, alloca_set)
      | LV_Ptr -> (op, extra, alloca_set)
      | _ ->
          raise
            (Failure
               (Printf.sprintf
                  "Indirect call operand does not have function type: %s has \
                   type %s"
                  (var_name v)
                  (string_of_lltype (ty_of_operand op)))))

let lower_rvalue_rhs (ctx : lower_ctx) (alloca_set : StringSet.t)
    (rv : Rir.rvalue) : instr_rhs * instruction list * StringSet.t =
  match rv.node with
  | Rir.RR_BinOp { op; lhs; rhs } ->
      let lhs', extra1, alloca_set = lower_operand ctx alloca_set lhs in
      let rhs', extra2, alloca_set = lower_operand ctx alloca_set rhs in
      if
        match op with
        | CR_Eq | CR_Ne | CR_Lt | CR_Le | CR_Gt | CR_Ge -> true
        | _ -> false
      then
        let operand_ty =
          match lhs with RR_OConstant (_, ty) -> ty.ty | RR_OVar v -> v.ty.ty
        in
        ( LV_ICmp (lower_compare_integer op operand_ty, lhs', rhs'),
          extra1 @ extra2,
          alloca_set )
      else if is_float_ir_type rv.ty.ty then
        ( LV_FBinOp (lower_float_binop op, lhs', rhs'),
          extra1 @ extra2,
          alloca_set )
      else
        ( LV_IBinOp (lower_integer_binop op rv.ty.ty, lhs', rhs'),
          extra1 @ extra2,
          alloca_set )
  | Rir.RR_UnOp { op; operand } -> (
      let value, extra, alloca_set = lower_operand ctx alloca_set operand in
      let value_ty = ty_of_operand value in
      match op with
      | CR_Neg ->
          if is_float_ir_type rv.ty.ty then
            ( LV_FBinOp (LV_FSub, LV_Constant (LV_Float 0.0, value_ty), value),
              extra,
              alloca_set )
          else
            ( LV_IBinOp (LV_ISub, LV_Constant (LV_Integer 0L, value_ty), value),
              extra,
              alloca_set )
      | CR_Not -> (LV_IBinOp (LV_IBitXor, value, i1 true), extra, alloca_set)
      | CR_BitNot ->
          ( LV_IBinOp
              (LV_IBitXor, value, LV_Constant (LV_Integer (-1L), value_ty)),
            extra,
            alloca_set ))
  | Rir.RR_Runtime_call { fn_name; args; ret_ty } ->
      let alloca_set, args_results =
        List.fold_left_map
          (fun s a ->
            let o, e, s = lower_runtime_arg ctx s a in
            (s, (o, e)))
          alloca_set args
      in
      let args_ops, extra_list = List.split args_results in
      let extra = List.concat extra_list in
      let ret_ty =
        match ret_ty with Some ty -> lltype_of_ty ty | None -> LV_Void
      in
      let fn_name = Rir.runtime_op_name_to_string fn_name in
      (call_rhs ctx ~fn_name ~ret_ty ~args:args_ops, extra, alloca_set)
  | Rir.RR_Object_load _ ->
      fail "RR_Object_load must be lowered through lower_statement"
  | Rir.RR_Cast { src; to_ty } ->
      let src', extra, alloca_set = lower_operand ctx alloca_set src in
      (LV_Cast (LV_BitCast, src', lltype_of_ty to_ty), extra, alloca_set)
  | Rir.RR_Addr_fn { fn } ->
      let fn_ptr = global fn LV_Ptr in
      let ptr_ty = lltype_of_ty rv.ty in
      (LV_Cast (LV_BitCast, fn_ptr, ptr_ty), [], alloca_set)

let lower_statement (ctx : lower_ctx) (alloca_set : StringSet.t)
    (stmt : Rir.statement) : StringSet.t * instruction list =
  match stmt.node with
  | Rir.RR_Assign { dst; rvalue = { node = Rir.RR_Cast { src; to_ty }; _ } } ->
      let src', extra, alloca_set = lower_operand ctx alloca_set src in
      if ty_of_operand src' = lltype_of_ty to_ty then (
        Hashtbl.replace ctx.var_env dst.id src';
        (alloca_set, extra))
      else
        ( alloca_set,
          extra
          @ assign_rhs_to_var ctx dst
              (LV_Cast (LV_BitCast, src', lltype_of_ty to_ty)) )
  | Rir.RR_Assign
      {
        dst;
        rvalue = { node = Rir.RR_Object_load { obj; field_idx; value_ty }; _ };
      } ->
      let ptr_instrs, typed_ptr, alloca_set =
        lower_object_slot_ptr ctx alloca_set obj field_idx value_ty
      in
      ( alloca_set,
        ptr_instrs
        @ assign_rhs_to_var ctx dst
            (LV_Load { ptr = typed_ptr; ty = lltype_of_ty value_ty }) )
  | Rir.RR_Assign { dst; rvalue } ->
      let rhs, extra, alloca_set = lower_rvalue_rhs ctx alloca_set rvalue in
      (alloca_set, extra @ assign_rhs_to_var ctx dst rhs)
  | Rir.RR_Call { dst; target; args } ->
      let alloca_set, args_results =
        List.fold_left_map
          (fun s a ->
            let o, e, s = lower_operand ctx s a in
            (s, (o, e)))
          alloca_set args
      in
      let args_ops, extra_list = List.split args_results in
      let extra = List.concat extra_list in
      let ret_ty = lltype_of_ty dst.ty in
      let fn_op, extra2, alloca_set =
        lower_target_operand ctx alloca_set target args_ops ret_ty
      in
      let rhs = LV_Call { fn = fn_op; args = args_ops; ret_ty } in
      (alloca_set, extra @ extra2 @ assign_rhs_to_var ctx dst rhs)
  | Rir.RR_Runtime_call { dst; call = { fn_name; args; ret_ty = _ } } ->
      let alloca_set, args_results =
        List.fold_left_map
          (fun s a ->
            let o, e, s = lower_runtime_arg ctx s a in
            (s, (o, e)))
          alloca_set args
      in
      let args_ops, extra_list = List.split args_results in
      let extra = List.concat extra_list in
      let ret_ty = lltype_of_ty dst.ty in
      let fn_name = Rir.runtime_op_name_to_string fn_name in
      let rhs = call_rhs ctx ~fn_name ~ret_ty ~args:args_ops in
      (alloca_set, extra @ assign_rhs_to_var ctx dst rhs)
  | Rir.RR_Object_store { obj; field_idx; value; value_ty } ->
      let ptr_instrs, typed_ptr, alloca_set =
        lower_object_slot_ptr ctx alloca_set obj field_idx value_ty
      in
      let value_ops, extra, alloca_set = lower_operand ctx alloca_set value in
      (alloca_set, ptr_instrs @ extra @ [ LV_Store (value_ops, typed_ptr) ])
  | Rir.RR_Move { dst; src } ->
      let val_ty = lltype_of_ty dst.ty in
      let ptr_op = LV_Local (var_name dst, LV_Ptr) in
      Hashtbl.replace ctx.var_env dst.id ptr_op;
      let src_ops, extra, alloca_set = lower_operand ctx alloca_set src in
      ( StringSet.add (var_name dst) alloca_set,
        extra
        @ [ LV_Assign (ptr_op, LV_Alloca val_ty); LV_Store (src_ops, ptr_op) ]
      )
  | Rir.RR_Store_global { global = global_name; value } ->
      let gv, extra, alloca_set = lower_operand ctx alloca_set value in
      (alloca_set, extra @ [ LV_Store (gv, global global_name LV_Ptr) ])
  | Rir.RR_Nop -> (alloca_set, [ LV_Comment "nop" ])

let lower_terminator (ctx : lower_ctx) (alloca_set : StringSet.t)
    (term : Rir.terminator) : terminator * instruction list * StringSet.t =
  match term.node with
  | RR_Goto id ->
      let label_id = Hashtbl.find ctx.block_label_map id in
      (LV_Br (label_of_block_id label_id), [], alloca_set)
  | RR_CondBr { cond; then_block; else_block } ->
      let then_label_id = Hashtbl.find ctx.block_label_map then_block in
      let else_label_id = Hashtbl.find ctx.block_label_map else_block in
      let cond_op, extra, alloca_set =
        lower_operand ctx alloca_set (RR_OVar cond)
      in
      ( LV_CondBr
          ( cond_op,
            label_of_block_id then_label_id,
            label_of_block_id else_label_id ),
        extra,
        alloca_set )
  | RR_Switch { scrutinee; cases; default_block } ->
      let scrutinee_op, extra, alloca_set =
        lower_operand ctx alloca_set (RR_OVar scrutinee)
      in
      let default_label =
        match default_block with
        | Some id -> label_of_block_id (Hashtbl.find ctx.block_label_map id)
        | None -> "switch_default_unreachable"
      in
      let cases' =
        List.map
          (fun (c : switch_case_node) ->
            ( LV_Constant (LV_Integer (Int64.of_int c.value), LV_I64),
              label_of_block_id
                (Hashtbl.find ctx.block_label_map c.target_block) ))
          cases
      in
      (LV_Switch (scrutinee_op, default_label, cases'), extra, alloca_set)
  | RR_Return value_opt -> (
      match value_opt with
      | None -> (LV_Ret None, [], alloca_set)
      | Some op ->
          let op', extra, alloca_set = lower_operand ctx alloca_set op in
          (LV_Ret (Some op'), extra, alloca_set))

let unique_blocks (fn : Rir.function_rir) : Rir.block list =
  let seen = Hashtbl.create 16 in
  let all = fn.entry_block :: fn.blocks in
  List.filter
    (fun (b : Rir.block) ->
      if Hashtbl.mem seen b.id then false
      else (
        Hashtbl.add seen b.id true;
        true))
    all

let var_name_of_instr (instr : instruction) : string option =
  match instr with
  | LV_Assign (LV_Local (name, _), LV_Alloca _) -> Some name
  | _ -> None

let hoist_allocas (blocks : block list) : block list =
  let is_static_alloca instr =
    match instr with LV_Assign (_, LV_Alloca _) -> true | _ -> false
  in
  let is_not_static_alloca instr = not (is_static_alloca instr) in
  let all_static_alloca =
    List.map
      (fun block -> List.filter is_static_alloca block.instructions)
      blocks
    |> List.flatten
  in
  let rest_blocks =
    List.map
      (fun block ->
        {
          block with
          instructions = List.filter is_not_static_alloca block.instructions;
        })
      blocks
  in
  let deduped =
    let seen = Hashtbl.create 16 in
    List.filter
      (fun instr ->
        match var_name_of_instr instr with
        | Some name when Hashtbl.mem seen name -> false
        | Some name ->
            Hashtbl.add seen name true;
            true
        | None -> true)
      all_static_alloca
  in
  match rest_blocks with
  | entry :: rest ->
      { entry with instructions = deduped @ entry.instructions } :: rest
  | [] -> []

let lower_function (runtime_decls : (string, lltype) Hashtbl.t)
    (fn_sigs : (string, fn_sig) Hashtbl.t)
    (ffi_syli_names : (string, string) Hashtbl.t) (known_globals : StringSet.t)
    (str_data : (string, string) Hashtbl.t) (fn : Rir.function_rir) : func =
  let block_label_map = Hashtbl.create 16 in
  List.iter
    (fun (b : Rir.block) -> Hashtbl.add block_label_map b.id b.label_id)
    (fn.entry_block :: fn.blocks);
  let ctx =
    {
      var_env = Hashtbl.create 64;
      runtime_decls;
      fn_sigs;
      ffi_syli_names;
      known_globals;
      next_reg = ref 0;
      block_label_map;
      str_data;
    }
  in
  let params =
    List.map
      (fun (v : Rir.var) ->
        let name = var_name v in
        let llty = lltype_of_ty v.ty in
        Hashtbl.replace ctx.var_env v.id (local name llty);
        (llty, name))
      fn.params
  in
  List.iter
    (fun (v : Rir.var) ->
      if not (Hashtbl.mem ctx.var_env v.id) then
        Hashtbl.replace ctx.var_env v.id
          (local (var_name v) (lltype_of_ty v.ty)))
    fn.locals;
  let blocks =
    unique_blocks fn
    |> List.fold_left_map
         (fun alloca_set (b : Rir.block) ->
           let alloca_set, stmt_instrs =
             List.fold_left_map
               (fun s stmt ->
                 let s', instrs = lower_statement ctx s stmt in
                 (s', instrs))
               alloca_set b.statements
             |> fun (s, instrs) -> (s, List.concat instrs)
           in
           let term, extra, alloca_set =
             lower_terminator ctx alloca_set b.terminator
           in
           ( alloca_set,
             {
               label = label_of_block_id b.label_id;
               instructions = stmt_instrs @ extra;
               terminator = term;
             } ))
         StringSet.empty
    |> snd |> hoist_allocas
    |> fun bs ->
    let need_unreachable =
      let has_no_default_switch (b : Rir.block) =
        match b.terminator.node with
        | RR_Switch { default_block = None; _ } -> true
        | _ -> false
      in
      has_no_default_switch fn.entry_block
      || List.exists has_no_default_switch fn.blocks
    in
    if need_unreachable then
      bs
      @ [
          {
            label = "switch_default_unreachable";
            instructions = [];
            terminator = LV_Unreachable;
          };
        ]
    else bs
  in
  {
    name = fn.name;
    ret_type = lltype_of_ty fn.return_ty;
    params;
    blocks;
    linkage =
      (match fn.visibility with CR_Public -> External | CR_Private -> Private);
  }

let build_fn_sig_table (prog : Rir.program_rir) : (string, fn_sig) Hashtbl.t =
  let tbl = Hashtbl.create 64 in
  List.iter
    (fun (fn : Rir.function_rir) ->
      let params =
        List.map (fun (v : Rir.var) -> lltype_of_ty v.ty) fn.params
      in
      let ret = lltype_of_ty fn.return_ty in
      Hashtbl.replace tbl fn.name { params; ret })
    prog.functions;
  tbl

let lower_ffi_decl (ffi : Rir.ffi_external_function) : string * lltype =
  let lower = fun ty -> lltype_of_ty ty in
  let params = List.map lower ffi.params in
  (ffi.name, LV_Func (params, lower ffi.ret_ty))

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
  let ffi_syli_names = Hashtbl.create 16 in
  List.iter
    (fun (ffi : Rir.ffi_external_function) ->
      Hashtbl.replace ffi_syli_names ffi.syli_name ffi.name)
    prog.ffi_external_functions;
  let runtime_decls = Hashtbl.create 32 in
  let fn_sigs = build_fn_sig_table prog in
  let str_data = Hashtbl.create 16 in
  let known_globals =
    List.fold_left
      (fun set (gv : Rir.global_value) -> StringSet.add gv.name set)
      StringSet.empty prog.global_values
  in
  let lower_fn =
    lower_function runtime_decls fn_sigs ffi_syli_names known_globals str_data
  in
  let functions = List.map lower_fn prog.functions in
  let runtime_declarations =
    Hashtbl.to_seq runtime_decls |> List.of_seq |> List.sort compare
  in
  let ffi_declarations = List.map lower_ffi_decl prog.ffi_external_functions in
  let declarations = runtime_declarations @ ffi_declarations in
  let globals =
    let str_globals =
      Hashtbl.fold
        (fun s name acc ->
          {
            g_name = name;
            g_type = LV_Array (String.length s, LV_I8);
            g_init = Some (LV_StringLit s);
            g_linkage = Private;
          }
          :: acc)
        str_data []
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

let lower = lower_program
let convert_program = lower_program

let to_string (prog : Rir.program_rir) : string =
  module_to_string (lower_program prog)
