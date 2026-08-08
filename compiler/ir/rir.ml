(** * RIR (Runtime Intermediate Representation) is a lower-level IR than SIR
    that is closer to the final codegen target.

    * It is designed to be easier to translate to any backend like C, LLVM, VM.*)

(** The runtime object general representation is:

    {[
      struct Object:
        uint64_t header_word
        uint64_t meta_ref_count
        uint64_t value[]
    ]}

    So the values offset is 2 (header + meta). *)
let values_offset = 2

type runtime_op_name =
  | RR_RT_get_object_length
  | RR_RT_get_object_tag
  | RR_RT_gc_cycle
  | RR_RT_object_raw_copy
  | RR_RT_object_copy
  | RR_RT_object_check_mutation
  | RR_RT_object_borrow
  | RR_RT_object_share
  | RR_RT_object_own
  | RR_RT_object_release
  | RR_RT_object_alloc

let runtime_op_name_to_string = function
  | RR_RT_get_object_length -> "syli_rt_get_object_length"
  | RR_RT_get_object_tag -> "syli_rt_get_object_tag"
  | RR_RT_gc_cycle -> "syli_rt_gc_cycle"
  | RR_RT_object_raw_copy -> "syli_rt_object_raw_copy"
  | RR_RT_object_copy -> "syli_rt_object_copy"
  | RR_RT_object_check_mutation -> "syli_rt_ownership_notify_mutation"
  | RR_RT_object_borrow -> "syli_rt_ownership_borrow"
  | RR_RT_object_share -> "syli_rt_ownership_share"
  | RR_RT_object_own -> "syli_rt_ownership_own"
  | RR_RT_object_release -> "syli_rt_ownership_release"
  | RR_RT_object_alloc -> "syli_rt_ownership_alloc_object"

type id = Cir.id
type qualified_name = Cir.qualified_name
type binop = Cir.binop
type unop = Cir.unop
type visibility = Cir.visibility
type cyclic_prop = Oir.cyclic_prop

let expr_id_counter = ref 0

let fresh_id () =
  incr expr_id_counter;
  !expr_id_counter

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
  | RR_Obj_Ptr of cyclic_prop
  | RR_FnPtr
  | RR_Char
  | RR_Str
  | RR_Void
  | RR_Arrow of ir_type list * ir_type

type constant =
  | RR_IntLit of string
  | RR_FloatLit of string
  | RR_BoolLit of string
  | RR_StringLit of string
  | RR_CharLit of string
  | RR_Null

and ty = { id : int; ty : ir_type }

type var = { id : id; fullname : string; ty : ty }
type operand = RR_OConstant of constant * ty | RR_OVar of var
type call_target = Direct of qualified_name | Indirect of var

type runtime_call = {
  fn_name : runtime_op_name;
  args : operand list;
  ret_ty : ty option;
}

type rvalue = { id : int; node : rvalue_node; ty : ty }
and statement = { id : int; node : statement_node; ty : ty }

and rvalue_node =
  | RR_BinOp of { op : binop; lhs : operand; rhs : operand }
  | RR_UnOp of { op : unop; operand : operand }
  | RR_Runtime_call of runtime_call
  | RR_Object_load of { obj : operand; field_idx : operand; value_ty : ty }
  | RR_Cast of { src : operand; to_ty : ty }
  | RR_Addr_fn of { fn : qualified_name }
      (** Materialize the address of a known function as a pointer value *)

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

type terminator = { id : int; node : terminator_node }

and terminator_node =
  | RR_Goto of id
  | RR_Switch of {
      scrutinee : var;
      cases : switch_case_node list;
      default_block : id option;
    }
  | RR_CondBr of { cond : var; then_block : id; else_block : id }
  | RR_Return of operand option

and switch_case_node = { value : int; target_block : id }

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

(* External function declaration *)
type ffi_external_function = {
  name : string;  (** C name used for linking (e.g., "syli_print_i64") *)
  syli_name : string;
      (** Qualified Syli name (e.g., "syliTest_binary.syli_print_i64") *)
  ret_ty : ty;
  params : ty list;
  calling_convention : string option;
}

type global_value = {
  name : qualified_name;
  init_fn_name : qualified_name;
  value : constant;
  ty : ty;
  visibility : visibility;
}

type program_rir = {
  name : string;
  type_defs : (string * ty) list;
  functions : function_rir list;
  global_values : global_value list;
  ffi_external_functions : ffi_external_function list;
}
