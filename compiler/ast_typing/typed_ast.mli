(** This module defines the typed AST types produced by the type-checking pass
    and consumed by the lowering passes. *)

type path = string list
(** A dotted path of module names. *)

type location = { start_pos : int; end_pos : int; filename : string }
(** Source location in the input file. *)

and ident = { name : string; id : int; fullname : string list; loc : location }
(** A name with unique ID, full path, and source location. *)

val dummy_loc : location
(** A placeholder location used for synthetic nodes. *)

(** Mutability flag for typed bindings. *)
type mut_flag = TMutable | TImmutable

(** Recursion flag for typed let-bindings. *)
type rec_flag = TRecursive | TNonRecursive

(** Primitive constant types in the typed AST. *)
type constant_ty =
  | TTy_Int8
  | TTy_Int16
  | TTy_Int32
  | TTy_Int64
  | TTy_UInt8
  | TTy_UInt16
  | TTy_UInt32
  | TTy_UInt64
  | TTy_Bool
  | TTy_Unit
  | TTy_Float
  | TTy_Double
  | TTy_StringLit
  | TTy_CharLit

type ty = { ty_desc : ty_desc }
(** A type node in the typed AST. *)

(** The description of a typed type. *)
and ty_desc =
  | TTy_Var of int
  | TTy_Any
  | TTy_Constant of constant_ty
  | TTy_Arrow of ty list * ty
  | TTy_Tuple of ty list
  | TTy_Array of ty
  | TTy_Defined of { name : ident; args : ty list }

and variant_constructor_decl = {
  id : int;
  name : ident;
  arg : ty option;
  loc : location;
}
(** A variant constructor declaration in the typed AST. *)

and record_field_decl = {
  id : int;
  field_name : ident;
  field_ty : ty;
  field_mut : mut_flag;
  loc : location;
}
(** A record field declaration in the typed AST. *)

(** Description of a type declaration body. *)
type ty_decl_desc =
  | TTydef_Alias of ty
  | TTydef_Record of record_field_decl list
  | TTydef_Variant of variant_constructor_decl list
  | TTydef_Abstract

type ty_decl = {
  id : int;
  name : ident;
  params : ident list;
  def : ty_decl_desc;
  annotations : string list;
  loc : location;
}
(** A full type declaration in the typed AST. *)

(** Logical negation unary operator. *)
type unop_logical = TNot

(** Arithmetic negation unary operator. *)
type unop_arithmetic = TNeg

(** Bitwise negation unary operator. *)
type unop_bitwise = TBitNot

(** A unary operator (logical, arithmetic, or bitwise). *)
type unop =
  | TUnop_Logical of unop_logical
  | TUnop_Arithmetic of unop_arithmetic
  | TUnop_Bitwise of unop_bitwise

(** Comparison binary operators. *)
type binop_comparison = TEq | TNe | TLt | TLe | TGt | TGe

(** Arithmetic binary operators. *)
type binop_arithmetic = TAdd | TSub | TMul | TDiv | TMod

(** Logical binary operators. *)
type binop_logical = TAnd | TOr

(** Bitwise binary operators. *)
type binop_bitwise = TBitAnd | TBitOr | TBitXor | TLShift | TRShift

(** A binary operator (arithmetic, logical, bitwise, or comparison). *)
type binop =
  | TBinop_Arithmetic of binop_arithmetic
  | TBinop_Logical of binop_logical
  | TBinop_Bitwise of binop_bitwise
  | TBinop_Comparison of binop_comparison

(** A collection literal in the typed AST. *)
type collection =
  | TCol_List of expr list
  | TCol_Array of expr list
  | TCol_Map of (expr * expr) list
  | TCol_Set of expr list

and param = {
  pattern : pattern;
  mut_flag : mut_flag;
  param_ty : ty option;
  loc : location;
}
(** A function parameter with optional type annotation. *)

and lambda = {
  params : param list;
  body : expr;
  ret_ty : ty option;
  loc : location;
}
(** A lambda expression with typed parameters and body. *)

(** Kind of typed let-binding. *)
and let_kind = TLetVal | TLetFun

and letdef = {
  let_kind : let_kind;
  rec_flag : rec_flag;
  pattern : pattern;
  value : expr;
  ty_opt : ty option;
  loc : location;
}
(** A typed let definition. *)

and record_field = {
  id : int;
  field_name : ident;
  field_value : expr;
  loc : location;
}
(** A record field in an expression. *)

(** Descriptor for a constant literal value. *)
and constant_desc =
  | TConst_Unit
  | TConst_BoolLit of string
  | TConst_IntLit of string
  | TConst_FloatLit of string
  | TConst_CharLit of string
  | TConst_StringLit of string

and constant = { id : int; constant_desc : constant_desc; loc : location }
(** A constant literal with an ID and location. *)

and expr = { id : int; expr_desc : expr_desc; loc : location; ty : ty }
(** A typed expression with an ID, description, location, and type. *)

(** The description of a typed expression. *)
and expr_desc =
  | TExp_Constant of constant
  | TExp_Ident of ident
  | TExp_Tuple of expr list
  | TExp_Record of record_field list
  | TExp_Collection of collection
  | TExp_VariantConstructor of { name : ident; args : expr option }
  | TExp_ArrayCreate of { lambda_init : lambda; element_ty : ty; size : expr }
  | TExp_ArrayLength of expr
  | TExp_ArrayGet of { arr : expr; idx : expr }
  | TExp_ArraySet of { arr : expr; idx : expr; value : expr }
  | TExp_UnOp of unop * expr
  | TExp_BinOp of binop * expr * expr
  | TExp_Lambda of lambda
  | TExp_Apply of { closure_fun : expr; args : expr list }
  | TExp_Let of letdef
  | TExp_Assign of { target : expr; value : expr }
  | TExp_If of { cond : expr; then_branch : expr; else_branch : expr option }
  | TExp_While of { cond : expr; body : expr }
  | TExp_ForIn of { iter_var : pattern; iterable : expr; body : expr }
  | TExp_Loop of expr
  | TExp_Break of expr option
  | TExp_Continue
  | TExp_Return of expr option
  | TExp_Seq of expr list
  | TExp_Match of expr * pattern_case list
  | TExp_Field of { record : expr; field_name : string; idx : int }
  | TExp_Index of { collection : expr; index : expr }

and pattern_case = {
  id : int;
  pattern : pattern;
  when_opt : expr option;
  body : expr;
  loc : location;
  ty : ty;
}
(** A pattern-matching case with optional guard and inferred type. *)

(** Collection pattern (list, array, map, or set). *)
and collection_pattern_item =
  | TPat_List of pattern list
  | TPat_Array of pattern list
  | TPat_Map of (pattern * pattern) list
  | TPat_Set of pattern list

and pattern = { id : int; pattern_desc : pattern_desc; loc : location; ty : ty }
(** A pattern node with ID, description, location, and type. *)

(** The description of a typed pattern. *)
and pattern_desc =
  | TPat_Unit
  | TPat_BoolLit of string
  | TPat_IntLit of string
  | TPat_CharLit of string
  | TPat_StringLit of string
  | TPat_FloatLit of string
  | TPat_Ident of ident
  | TPat_Tuple of pattern list
  | TPat_Record of (string * pattern option) list
  | TPat_Constructor of string * pattern option
  | TPat_Collection of collection_pattern_item * ty option
  | TPat_Wildcard

(** Description of a typed signature item. *)
type signature_item_desc =
  | TSig_Fun of {
      name : ident;
      params : ty list;
      ret_ty : ty;
      external_fn : external_fn option;
    }
  | TSig_Type of ty_decl
  | TSig_Module of module_signature

and external_fn = {
  c_name : string;
  calling_convention : string option;
  loc : location;
}
(** An FFI external function declaration. *)

and signature_item = {
  id : int;
  signature_item_desc : signature_item_desc;
  loc : location;
}
(** A signature item with ID and location. *)

(** Description of a typed structure item. *)
and structure_item_desc =
  | TStr_Let of letdef
  | TStr_Fun of {
      rec_flag : rec_flag;
      name : ident;
      body : expr;
      ty_opt : ty option;
    }
  | TStr_TypeDef of ty_decl
  | TStr_ModuleStruct of module_structure
  | TStr_Signature of signature_item list

and structure_item = {
  id : int;
  structure_item_desc : structure_item_desc;
  loc : location;
}
(** A structure item with ID and location. *)

and module_signature = {
  id : int;
  name : ident;
  signature_items : signature_item list;
  loc : location;
}
(** A module signature (interface) in the typed AST. *)

and module_structure = {
  id : int;
  name : ident;
  structure_items : structure_item list;
  loc : location;
}
(** A module structure (implementation) in the typed AST. *)

type program = module_structure
(** A complete typed program is a module structure. *)
