(*  OIR - Object Intermediate Representation
    After closure lowering: no Make_closure, Partial_apply, Apply, Arrow, GenericTyp *)

type id = int
type qualified_name = string

let expr_id_counter = ref 0

let fresh_id () =
  incr expr_id_counter;
  !expr_id_counter

type mut_flag = Mutable | Immutable

type binop =
  | OR_Add
  | OR_Sub
  | OR_Mul
  | OR_Div
  | OR_Mod
  | OR_Eq
  | OR_Ne
  | OR_Lt
  | OR_Le
  | OR_Gt
  | OR_Ge
  | OR_BitAnd
  | OR_BitOr
  | OR_BitXor
  | OR_Shl
  | OR_Shr
  | OR_And
  | OR_Or

type unop = OR_Neg | OR_Not | OR_BitNot
type visibility = OR_Public | OR_Private

type ir_type =
  | OR_Bool
  | OR_I64
  | OR_I32
  | OR_I16
  | OR_I8
  | OR_U64
  | OR_U32
  | OR_U16
  | OR_U8
  | OR_Float
  | OR_Double
  | OR_FnPtr
  | OR_Obj of { named : string option; args : ty list }
  | OR_Ptr of ty  (** TODO: remove Ptr and replace arrow translation by Obj *)
  | OR_Void

and ty = { id : int; ir_type : ir_type }

type constant =
  | OR_IntLit of string
  | OR_FloatLit of string
  | OR_BoolLit of string
  | OR_StringLit of string
  | OR_CharLit of string
  | OR_Null

type object_layout =
  | OR_Record of { field_count : int; field_types : ty list; tag_variant : int }
  | OR_Array of { element_ty : ty; tag_variant : int }

and var = { id : id; name : string; ty : ty }
and operand = OR_OConstant of constant * ty | OR_OVar of var
and call_target = Direct of qualified_name | Direct_fn_ptr of { ptr : var }

type terminator = { id : int; node : terminator_node }

and terminator_node =
  | OR_Goto of id
  | OR_Switch of {
      scrutinee : var;
      cases : switch_case_node list;
      default_block : id option;
    }
  | OR_CondBr of { cond : var; then_block : id; else_block : id }
  | OR_Return of operand option

and switch_case_node = { value : int; target_block : id }

type rc_op =
  | OR_RC_incr
  | OR_RC_decr
  | OR_RC_check_release  (** Release when ref = 0*)
  | OR_RC_check_drop  (** Drop non escaping when ref = 0 *)
  | OR_RC_check_lost_cyclic_release
      (** Suspect lost cycle when a cyclic object is being to be release and its
          refcount > 1 this also could be optimize if we know for sure the
          object is hold by another object that could be release later *)
  | OR_RC_check_lost_cyclic_drop  (** For non escaping cyclic obj *)

type rvalue_node =
  | OR_BinOp of { op : binop; lhs : operand; rhs : operand }
  | OR_UnOp of { op : unop; operand : operand }
  | OR_Object_get of { obj : operand; field_idx : operand; value_ty : ty }
  | OR_Object_length of { obj : operand }
  | OR_Object_get_tag of { obj : operand }
  | OR_Cast of { src : operand; to_ty : ty }
  | OR_Move of { src : operand }
  | OR_Addr_fn of { fn : qualified_name }

type rvalue = { id : int; node : rvalue_node; ty : ty }
and statement = { id : int; node : statement_node; ty : ty }

and statement_node =
  | OR_Assign of { dst : var; rvalue : rvalue }
  | OR_Object_set of {
      obj : var;
      field_idx : operand;
      value : operand;
      value_ty : ty;
    }
  | OR_Object_create of {
      dst : var;
      size : operand;
      layout : object_layout;
      initializer_fn : qualified_name option;
    }
  | OR_Call of { dst : var; target : call_target; args : operand list }
  | OR_Store_global of { global : qualified_name; value : operand }
  | OR_RC_op of { op : rc_op; obj : var }
  | OR_GC_cycle  (** GC running *)
  | OR_Nop

type block = {
  id : id;
  label_id : id;
  statements : statement list;
  terminator : terminator;
  pred_blocks : block list;
  succ_blocks : block list;
}

type function_oir = {
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
  name : string;
  syli_name : string;
  ret_ty : ty;
  params : ty list;
  calling_convention : string option;
}

type global_value = {
  name : qualified_name;
  init_fn : function_oir;
  value : constant;
  ty : ty;
  visibility : visibility;
}

type module_oir = {
  name : string;
  type_defs : (string * ty) list;
  functions : function_oir list;
  global_values : global_value list;
  ffi_external_functions : ffi_external_function list;
}
