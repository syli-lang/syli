(** RIR — Runtime Intermediate Representation.

    RIR is a lower-level IR than SIR, designed for straightforward translation
    to backends such as C, LLVM, or a VM. *)

val values_offset : int

type runtime_op_name =
  | RR_RT_rc_alloc_object
  | RR_RT_get_object_length
  | RR_RT_get_object_tag
  | RR_RT_gc_cycle
  | RR_RT_object_incr
  | RR_RT_object_decr
  | RR_RT_object_decr_n
  | RR_RT_object_decr_drop
  | RR_RT_object_check_release
  | RR_RT_object_check_drop
  | RR_RT_object_check_lost_cyclic_release
  | RR_RT_object_check_lost_cyclic_drop
  | RR_RT_object_raw_copy
  | RR_RT_object_copy
  | RR_RT_object_check_mutation

val runtime_op_name_to_string : runtime_op_name -> string

type id = int
type qualified_name = string

val fresh_id : unit -> int

type binop = Cir.binop
type unop = Cir.unop
type visibility = Cir.visibility

type ir_type =
  | RR_Bool
  | RR_I64
  | RR_I32
  | RR_I16
  | RR_I8
  | RR_U64
  | RR_U32
  | RR_U16
  | RR_U8
  | RR_Float
  | RR_Double
  | RR_Ptr of ir_type
  | RR_Void
  | RR_Arrow of ir_type list * ir_type

val object_ptr_ty : ir_type

type constant =
  | RR_IntLit of qualified_name
  | RR_FloatLit of qualified_name
  | RR_BoolLit of qualified_name
  | RR_StringLit of qualified_name
  | RR_CharLit of qualified_name
  | RR_Null

and ty = { id : id; ty : ir_type }

type var = { id : id; fullname : qualified_name; ty : ty }
type operand = RR_OConstant of constant * ty | RR_OVar of var
type call_target = Direct of qualified_name | Indirect of var

type runtime_call = {
  fn_name : runtime_op_name;
  args : operand list;
  ret_ty : ty option;
}

type rvalue = { id : id; node : rvalue_node; ty : ty }
and statement = { id : id; node : statement_node; ty : ty }

and rvalue_node =
  | RR_BinOp of { op : binop; lhs : operand; rhs : operand }
  | RR_UnOp of { op : unop; operand : operand }
  | RR_Runtime_call of runtime_call
  | RR_Object_load of { obj : operand; field_idx : operand; value_ty : ty }
  | RR_Cast of { src : operand; to_ty : ty }
  | RR_Addr_fn of { fn : qualified_name }

and statement_node =
  | RR_Assign of { dst : var; rvalue : rvalue }
  | RR_Call of { dst : var; target : call_target; args : operand list }
  | RR_Runtime_call of { dst : var; call : runtime_call }
  | RR_Object_store of {
      obj : operand;
      field_idx : operand;
      value : operand;
      value_ty : ty;
    }
  | RR_Store_global of { global : qualified_name; value : operand }
  | RR_Move of { dst : var; src : operand }
  | RR_Nop

type terminator = { id : id; node : terminator_node }

and terminator_node =
  | RR_Goto of id
  | RR_Switch of {
      scrutinee : var;
      cases : switch_case_node list;
      default_block : id option;
    }
  | RR_CondBr of { cond : var; then_block : id; else_block : id }
  | RR_Return of operand option

and switch_case_node = { value : id; target_block : id }

type block = {
  id : id;
  label_id : id;
  statements : statement list;
  terminator : terminator;
}

type function_rir = {
  id : id;
  name : qualified_name;
  params : var list;
  locals : var list;
  entry_block : block;
  blocks : block list;
  return_ty : ty;
  visibility : visibility;
}

type ffi_external_function = {
  name : qualified_name;
  syli_name : qualified_name;
  ret_ty : ty;
  params : ty list;
  calling_convention : qualified_name option;
}

type global_value = {
  name : qualified_name;
  init_fn_name : qualified_name;
  value : constant;
  ty : ty;
  visibility : visibility;
}

type program_rir = {
  name : qualified_name;
  type_defs : (qualified_name * ty) list;
  functions : function_rir list;
  global_values : global_value list;
  ffi_external_functions : ffi_external_function list;
}
