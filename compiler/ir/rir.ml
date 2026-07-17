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

(* TODO: drop functions for non escaping objects is not ready yet, a work need
  to be done inside the runtime before:
    - candidates list for non escaping cyclic objects
    - during freeing dropped objects free the cyclic objects too
*)
let runtime_op_name_to_string = function
  | RR_RT_rc_alloc_object -> "syli_rt_rc_alloc_object"
  | RR_RT_get_object_length -> "syli_rt_get_object_length"
  | RR_RT_get_object_tag -> "syli_rt_get_object_tag"
  | RR_RT_gc_cycle -> "syli_rt_gc_cycle"
  | RR_RT_object_incr -> "syli_rt_object_incr"
  | RR_RT_object_decr -> "syli_rt_object_decr"
  | RR_RT_object_decr_n -> "syli_rt_object_decr_n"
  | RR_RT_object_decr_drop -> "syli_rt_object_decr_drop"
  | RR_RT_object_check_release -> "syli_rt_object_check_release"
  | RR_RT_object_check_drop -> "syli_rt_object_check_drop"
  | RR_RT_object_check_lost_cyclic_release ->
      "syli_rt_object_check_lost_cyclic_release"
  | RR_RT_object_check_lost_cyclic_drop ->
      "syli_rt_object_check_lost_cyclic_drop"
  | RR_RT_object_raw_copy -> "syli_rt_object_raw_copy"
  | RR_RT_object_copy -> "syli_rt_object_copy"
  | RR_RT_object_check_mutation -> "syli_rt_object_check_mutation"

type id = Cir.id
type qualified_name = Cir.qualified_name
type binop = Cir.binop
type unop = Cir.unop
type visibility = Cir.visibility

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
  | RR_Obj_Ptr of ir_type
  | RR_FnPtr
  | RR_Char
  | RR_Str
  | RR_Void
  | RR_Arrow of ir_type list * ir_type

let object_ptr_ty = RR_Obj_Ptr RR_I64

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
