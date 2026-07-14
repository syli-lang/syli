open Cir

type subst = (int, ty) Hashtbl.t

let rec apply_subst_ty subst ty =
  let ir_type = subst_ir_type subst ty.ir_type in
  if ir_type = ty.ir_type then ty else { id = fresh_id (); ir_type }

and subst_ir_type subst = function
  | CR_GenericTyp { type_var } -> (
      match Hashtbl.find_opt subst type_var with
      | Some ty -> ty.ir_type
      | None -> CR_GenericTyp { type_var })
  | CR_Arrow (args, ret) ->
      CR_Arrow (List.map (apply_subst_ty subst) args, apply_subst_ty subst ret)
  | CR_Ptr ty -> CR_Ptr (apply_subst_ty subst ty)
  | CR_Obj { named; args } ->
      CR_Obj { named; args = List.map (apply_subst_ty subst) args }
  | other -> other

let type_of_param (var : var) = var.ty

let rec subst_object_layout subst = function
  | CR_Record { field_count; field_types; tag_variant } ->
      CR_Record
        {
          field_count;
          field_types = List.map (apply_subst_ty subst) field_types;
          tag_variant;
        }
  | CR_Array { element_ty; tag_variant } ->
      CR_Array { element_ty = apply_subst_ty subst element_ty; tag_variant }

let subst_var subst (v : var) = { v with ty = apply_subst_ty subst v.ty }

let subst_operand subst = function
  | CR_OConstant (c, ty) -> CR_OConstant (c, apply_subst_ty subst ty)
  | CR_OVar v -> CR_OVar (subst_var subst v)

let rec subst_rvalue subst (rvalue : rvalue) : rvalue =
  let node : rvalue_node =
    match rvalue.node with
    | CR_BinOp { op; lhs; rhs } ->
        CR_BinOp
          { op; lhs = subst_operand subst lhs; rhs = subst_operand subst rhs }
    | CR_UnOp { op; operand } ->
        CR_UnOp { op; operand = subst_operand subst operand }
    | CR_Object_get { obj; field_idx; value_ty } ->
        CR_Object_get
          {
            obj = subst_operand subst obj;
            field_idx = subst_operand subst field_idx;
            value_ty = apply_subst_ty subst value_ty;
          }
    | CR_Object_length { obj } ->
        CR_Object_length { obj = subst_operand subst obj }
    | CR_Object_get_tag { obj } ->
        CR_Object_get_tag { obj = subst_operand subst obj }
    | CR_Cast { src; to_ty } ->
        CR_Cast
          { src = subst_operand subst src; to_ty = apply_subst_ty subst to_ty }
    | CR_Move { src } -> CR_Move { src = subst_operand subst src }
    | CR_Addr_fn _ as n -> n
  in
  { id = rvalue.id; node; ty = apply_subst_ty subst rvalue.ty }

let subst_statement subst stmt =
  let node =
    match stmt.node with
    | CR_Assign { dst; rvalue } ->
        CR_Assign
          { dst = subst_var subst dst; rvalue = subst_rvalue subst rvalue }
    | CR_Object_set { obj; field_idx; value; value_ty } ->
        CR_Object_set
          {
            obj = subst_var subst obj;
            field_idx = subst_operand subst field_idx;
            value = subst_operand subst value;
            value_ty = apply_subst_ty subst value_ty;
          }
    | CR_Object_create { dst; size; layout; initializer_fn } ->
        CR_Object_create
          {
            dst = subst_var subst dst;
            size = subst_operand subst size;
            layout = subst_object_layout subst layout;
            initializer_fn;
          }
    | CR_Call { dst; target; args } ->
        let subst_target = function
          | Direct _ as d -> d
          | Direct_fn_ptr { ptr } -> Direct_fn_ptr { ptr = subst_var subst ptr }
          | Apply { closure } -> Apply { closure = subst_var subst closure }
        in
        CR_Call
          {
            dst = subst_var subst dst;
            target = subst_target target;
            args = List.map (subst_operand subst) args;
          }
    | CR_Partial_apply { dst; closure; new_args } ->
        CR_Partial_apply
          {
            dst = subst_var subst dst;
            closure = subst_var subst closure;
            new_args = List.map (subst_operand subst) new_args;
          }
    | CR_Make_closure { dst; free_vars; captured_args; fn; initializer_fn } ->
        CR_Make_closure
          {
            dst = subst_var subst dst;
            free_vars = List.map (subst_var subst) free_vars;
            captured_args = List.map (subst_operand subst) captured_args;
            fn;
            initializer_fn;
          }
    | CR_Store_global { global; value } ->
        CR_Store_global { global; value = subst_operand subst value }
    | CR_Nop -> CR_Nop
  in
  { id = stmt.id; node; ty = apply_subst_ty subst stmt.ty }

let subst_terminator subst (term : terminator) : terminator =
  let node : terminator_node =
    match term.node with
    | CR_Goto _ as n -> n
    | CR_Switch { scrutinee; cases; default_block } ->
        CR_Switch
          { scrutinee = subst_var subst scrutinee; cases; default_block }
    | CR_CondBr { cond; then_block; else_block } ->
        CR_CondBr { cond = subst_var subst cond; then_block; else_block }
    | CR_Return operand -> CR_Return (Option.map (subst_operand subst) operand)
  in
  { id = term.id; node }

let subst_block subst block =
  {
    block with
    statements = List.map (subst_statement subst) block.statements;
    terminator = subst_terminator subst block.terminator;
  }

let clone_function id (fn : function_cir) new_name subst =
  let blocks : block list = List.map (subst_block subst) fn.blocks in
  let entry_id = fn.entry_block.id in
  let rec find_entry (blocks' : block list) : block =
    match blocks' with
    | [] -> failwith "specialization: missing entry block"
    | block :: rest -> if block.id = entry_id then block else find_entry rest
  in
  let entry_block : block = find_entry blocks in
  {
    fn with
    id;
    name = new_name;
    params = List.map (subst_var subst) fn.params;
    locals = List.map (subst_var subst) fn.locals;
    entry_block;
    blocks;
    return_ty = apply_subst_ty subst fn.return_ty;
  }
