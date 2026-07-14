(** This module defines the CIR (Syli Intermediate Representation) types. CIR is
    a control-flow-graph-based IR used before LLVM lowering. *)

type id = int
(** A unique identifier for CIR nodes. *)

type qualified_name = string
(** A qualified name (e.g. "module.function"). *)

val expr_id_counter : int ref
(** Global counter for generating fresh CIR IDs. *)

val fresh_id : unit -> int
(** Returns a fresh unique integer ID. *)

(** Mutability flag for CIR variables. *)
type mut_flag = Mutable | Immutable

(** CIR binary operators. *)
type binop =
  | CR_Add
  | CR_Sub
  | CR_Mul
  | CR_Div
  | CR_Mod
  | CR_Eq
  | CR_Ne
  | CR_Lt
  | CR_Le
  | CR_Gt
  | CR_Ge
  | CR_BitAnd
  | CR_BitOr
  | CR_BitXor
  | CR_Shl
  | CR_Shr
  | CR_And
  | CR_Or

(** CIR unary operators. *)
type unop = CR_Neg | CR_Not | CR_BitNot

(** Visibility of a CIR function or global. *)
type visibility = CR_Public | CR_Private

(** CIR type kinds. *)
type ir_type =
  | CR_Bool
  | CR_I64
  | CR_I32
  | CR_I16
  | CR_I8
  | CR_U64
  | CR_U32
  | CR_U16
  | CR_U8
  | CR_Float
  | CR_Double
  | CR_FnPtr
  | CR_Obj of { named : string option; args : ty list }
  | CR_Ptr of ty
  | CR_Void
  | CR_GenericTyp of { type_var : int }
  | CR_Arrow of ty list * ty

and ty = { id : int; ir_type : ir_type }
(** A CIR type node with ID. *)

(** A literal constant value in CIR. *)
type constant =
  | CR_IntLit of string
  | CR_FloatLit of string
  | CR_BoolLit of string
  | CR_StringLit of string
  | CR_CharLit of string
  | CR_Null

(** Layout of a heap-allocated object. *)
type object_layout =
  | CR_Record of { field_count : int; field_types : ty list; tag_variant : int }
  | CR_Array of { element_ty : ty; tag_variant : int }

and var = { id : id; name : string; ty : ty }
(** A CIR variable with name, type, and ID. *)

(** An operand: either a constant or a variable reference. *)
and operand = CR_OConstant of constant * ty | CR_OVar of var

(** A call target: direct name, function pointer, or closure apply. *)
and call_target =
  | Direct of qualified_name
  | Direct_fn_ptr of { ptr : var }
  | Apply of { closure : var }

type terminator = { id : int; node : terminator_node }
(** A block terminator with ID. *)

(** The node of a block terminator. *)
and terminator_node =
  | CR_Goto of id
  | CR_Switch of {
      scrutinee : var;
      cases : switch_case_node list;
      default_block : id option;
    }
  | CR_CondBr of { cond : var; then_block : id; else_block : id }
  | CR_Return of operand option

and switch_case_node = { value : int; target_block : id }
(** A switch case mapping an integer value to a target block. *)

(** Rvalue computation node. *)
type rvalue_node =
  | CR_BinOp of { op : binop; lhs : operand; rhs : operand }
  | CR_UnOp of { op : unop; operand : operand }
  | CR_Object_get of { obj : operand; field_idx : operand; value_ty : ty }
  | CR_Object_length of { obj : operand }
  | CR_Object_get_tag of { obj : operand }
  | CR_Cast of { src : operand; to_ty : ty }
  | CR_Move of { src : operand }
  | CR_Addr_fn of { fn : qualified_name }

type rvalue = { id : int; node : rvalue_node; ty : ty }
(** An rvalue expression producing a value. *)

and statement = { id : int; node : statement_node; ty : ty }
(** A statement in a CIR block. *)

(** The node of a CIR statement. *)
and statement_node =
  | CR_Assign of { dst : var; rvalue : rvalue }
  | CR_Object_set of {
      obj : var;
      field_idx : operand;
      value : operand;
      value_ty : ty;
    }
  | CR_Object_create of {
      dst : var;
      size : operand;
      layout : object_layout;
      initializer_fn : qualified_name option;
    }
  | CR_Call of { dst : var; target : call_target; args : operand list }
  | CR_Make_closure of {
      dst : var;
      free_vars : var list;
      captured_args : operand list;
      fn : qualified_name;
      initializer_fn : qualified_name option;
    }
  | CR_Partial_apply of { dst : var; closure : var; new_args : operand list }
  | CR_Store_global of { global : qualified_name; value : operand }
  | CR_Nop

type block = {
  id : id;
  label_id : id;
  statements : statement list;
  terminator : terminator;
  pred_blocks : block list;
  succ_blocks : block list;
}
(** A basic block in a CIR function. *)

type function_cir = {
  id : id;
  name : qualified_name;
  params : var list;
  locals : var list;
  entry_block : block;
  blocks : block list;
  return_ty : ty;
  visibility : visibility;
}
(** A CIR function with entry block and control flow graph. *)

type ffi_external_function = {
  name : string;
  syli_name : string;
  ret_ty : ty;
  params : ty list;
  calling_convention : string option;
}
(** An FFI external function declaration in CIR form. *)

type global_value = {
  name : qualified_name;
  init_fn : function_cir;
  value : constant;
  ty : ty;
  visibility : visibility;
}
(** A global value in CIR form. *)

type module_cir = {
  name : string;
  type_defs : (string * ty) list;
  functions : function_cir list;
  global_values : global_value list;
  ffi_external_functions : ffi_external_function list;
}
(** A complete CIR module. *)
