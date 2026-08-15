(** This module defines the core (normalized) AST types produced after
    type-checking and used by the middle-end passes. *)

type path = string list
(** A dotted path of module names. *)

type ident = { name : string; fullname : string; path : path; id : int }
(** An identifier with name, full name, path, and unique ID. *)

(** Mutability flag for core AST bindings. *)
type mut_flag = CMutable | CImmutable

(** Recursion flag for core AST bindings. *)
type rec_flag = CRecursive | CNonRecursive

(** Primitive constant types in the core AST. *)
type constant_ty =
  | CTy_Int64
  | CTy_Int32
  | CTy_Int16
  | CTy_Int8
  | CTy_UInt64
  | CTy_UInt32
  | CTy_UInt16
  | CTy_UInt8
  | CTy_Unit
  | CTy_Bool
  | CTy_Float
  | CTy_Double
  | CTy_StringLit
  | CTy_CharLit

type ty = { ty_desc : ty_desc }
(** A type in the core AST. *)

(** The description of a core type. *)
and ty_desc =
  | CTy_Var of int
  | CTy_Constant of constant_ty
  | CTy_Arrow of ty list * ty
  | CTy_Tuple of ty list
  | CTy_Array of ty
  | CTy_Ref of ty
  | CTy_Defined of { name : ident; args : ty list }

and constructor_decl = {
  id : int;
  variant_tag : int;
  arg : constructor_arg option;
}
(** A variant constructor declaration with tag number. *)

and constructor_arg = Constr_ty of ty | Constr_record of record_field_ty list

and record_field_ty = {
  id : int;
  field_idx : int;
  field_ty : ty;
  field_mut : mut_flag;
}
(** A record field declaration with field index. *)

and ty_decl = {
  id : int;
  name : ident;
  params : string list;
  def : ty_decl_desc;
}
(** A full type declaration in the core AST. *)

(** Body of a core type declaration. *)
and ty_decl_desc =
  | CTydef_Alias of ty
  | CTydef_Variant of constructor_decl list
  | CTydef_Record of record_field_ty list
  | CTydef_Abstract

(** Logical negation unary operator. *)
type unop_logical = CNot

(** Arithmetic negation unary operator. *)
type unop_arithmetic = CNeg

(** Bitwise negation unary operator. *)
type unop_bitwise = CBitNot

(** Unary operator (logical, arithmetic, or bitwise). *)
type unop =
  | CUnop_Logical of unop_logical
  | CUnop_Arithmetic of unop_arithmetic
  | CUnop_Bitwise of unop_bitwise

(** Comparison binary operators. *)
type binop_comparison = CEq | CNe | CLt | CLe | CGt | CGe

(** Arithmetic binary operators. *)
type binop_arithmetic = CAdd | CSub | CMul | CDiv | CMod

(** Logical binary operators. *)
type binop_logical = CAnd | COr

(** Bitwise binary operators. *)
type binop_bitwise = CBitAnd | CBitOr | CBitXor | CLShift | CRShift

(** Binary operator (arithmetic, logical, bitwise, or comparison). *)
type binop =
  | CBinop_Arithmetic of binop_arithmetic
  | CBinop_Logical of binop_logical
  | CBinop_Bitwise of binop_bitwise
  | CBinop_Comparison of binop_comparison

type expr = { id : int; node : expr_node; ty : ty }
(** A core expression node with ID, node kind, and type. *)

and lambda = { params : ident list; body : expr; ret_ty : ty }
(** A lambda expression in the core AST. *)

and record_field = { field_idx : int; field_ty : ty; field_value : expr }
(** A record field in a core expression. *)

(** A literal constant value. *)
and constant =
  | CConst_Unit
  | CConst_IntLit of string
  | CConst_FloatLit of string
  | CConst_BoolLit of string
  | CConst_StringLit of string
  | CConst_CharLit of string

(** The description of a core expression node. *)
and expr_node =
  | CExp_Constant of constant
  | CExp_Ident of ident
  | CExp_UnOp of { op : unop; value : expr }
  | CExp_BinOp of { op : binop; lvalue : expr; rvalue : expr }
  | CExp_Record of record_field list
  | CExp_VariantConstructor of { tag : int; arg : expr option }
  | CExp_Field of { record : expr; field_idx : int }
  | CExp_FieldSet of { record : expr; field_idx : int; value : expr }
  | CExp_ArrayCreate of { element_ty : ty; size : expr }
  | CExp_ArrayLength of expr
  | CExp_ArrayGet of { arr : expr; idx : expr }
  | CExp_ArraySet of { arr : expr; idx : expr; value : expr }
  | CExp_Lambda of lambda
  | CExp_Apply of { closure_fun : expr; args : expr list }
  | CExp_Let of { rec_flag : rec_flag; name : ident; value : expr }
  | CExp_Loop of expr
  | CExp_Break of expr option
  | CExp_Continue
  | CExp_Return of expr option
  | CExp_Seq of expr list
  | CExp_If of { cond : expr; then_branch : expr; else_branch : expr option }
  | Exp_Match of { expr : expr; cases : pattern_case list }

and pattern_case = {
  id : int;
  pattern : pattern;
  when_condition : expr option;
  body : expr;
}

and pattern = { id : int; node : pattern_desc }
and pattern_record_field = { name : ident; pattern : pattern option }

and pattern_desc =
  | Pat_Unit
  | Pat_BoolLit of string
  | Pat_IntLit of string
  | Pat_CharLit of string
  | Pat_FloatLit of string
  | Pat_StringLit of string
  | Pat_Ident of ident
  | Pat_Record of pattern_record_field list
  | Pat_Constructor of { tag : int; pattern : pattern option }
  | Pat_Any

(** Description of a core signature item. *)
type signature_item_desc =
  | CSig_Fun of {
      name : ident;
      params : ty list;
      ret_ty : ty;
      external_fn : external_fn option;
    }
  | CSig_Type of ty_decl

and external_fn = { c_name : string; calling_convention : string option }
(** An FFI external function declaration. *)

and signature_item = { id : int; signature_item_desc : signature_item_desc }
(** A signature item with ID. *)

(** Description of a core structure item. *)
and structure_item_desc =
  | CStr_Let of { rec_flag : rec_flag; name : ident; value : expr }
  | CStr_TypeDef of ty_decl

and structure_item = { id : int; structure_item_desc : structure_item_desc }
(** A structure item with ID. *)

and module_core = {
  id : int;
  name : ident;
  structure_items : structure_item list;
  signature_items : signature_item list;
  has_main_function : bool;
}
(** A complete core module with structure and signature items. *)

type program_core = module_core
(** A complete core program is a single module. *)
