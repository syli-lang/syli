(** This module defines the typed AST types produced by the type-checking pass
    and consumed by the lowering passes. *)

type path = string list
(** A dotted path of module names. *)

type location = { start_pos : int; end_pos : int; filename : string }
(** Source location in the input file. *)

and ident = {
  name : string;
  id : int;
  path : string list;
  loc : location;
  is_operator : bool;
}
(** A name with unique ID, path, and source location; [is_operator] marks the
    dedicated operator namespace. *)

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
  | TTy_F32
  | TTy_F64
  | TTy_String
  | TTy_Char

type ty = { ty_desc : ty_desc }
(** A type node in the typed AST. *)

(** The description of a typed type. *)
and ty_desc =
  | TTy_Var of int
  | TTy_Any
  | TTy_Constant of constant_ty
  | TTy_Arrow of ty * ty
  | TTy_Tuple of ty list
  | TTy_Array of ty
  | TTy_Defined of { name : ident; args : ty list }

and variant_constructor_decl = {
  id : int;
  name : ident;
  arg : variant_constructor_arg option;
  tag : int;
  loc : location;
}
(** A variant constructor declaration in the typed AST. *)

and variant_constructor_arg =
  | Constr_ty of ty
  | Constr_record of record_field_decl list

and record_field_decl = {
  id : int;
  field_name : ident;
  field_idx : int;
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

and param = { pattern : pattern; param_ty : ty option; loc : location }
(** A function parameter with optional type annotation. *)

and lambda = {
  params : param list;
  body : expr;
  ret_ty : ty option;
  loc : location;
}
(** A lambda expression in the typed AST. *)

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
  field_idx : int;
  field_value : expr;
  loc : location;
}
(** A record field expression in the typed AST. *)

and constant_desc =
  | TConst_Unit
  | TConst_BoolLit of string
  | TConst_IntLit of string
  | TConst_FloatLit of string
  | TConst_CharLit of string
  | TConst_StringLit of string  (** Description of a typed literal constant. *)

and constant = { id : int; constant_desc : constant_desc; loc : location }
(** A literal constant in the typed AST. *)

and expr = { id : int; expr_desc : expr_desc; loc : location; ty : ty }
(** A typed expression node. *)

and expr_desc =
  | TExp_Constant of constant
  | TExp_Ident of ident
  | TExp_Tuple of { elements : expr list }
  | TExp_Record of { fields : record_field list }
  | TExp_VariantConstructor of { tag : int; name : ident; arg : expr option }
  | TExp_Array of { element_ty : ty; elements : expr list; size : expr }
  | TExp_Lambda of lambda
  | TExp_Apply of { closure_fun : expr; args : expr list }
  | TExp_Let of letdef
  | TExp_If of {
      condition : expr;
      then_branch : expr;
      else_branch : expr option;
    }
  | TExp_While of { condition : expr; body : expr }
  | TExp_Loop of { expr : expr }
  | TExp_Break of { expr_opt : expr option }
  | TExp_Continue
  | TExp_Return of { expr_opt : expr option }
  | TExp_Seq of { exprs : expr list }
  | TExp_Match of { expr : expr; cases : pattern_case list }
  | TExp_Field of { record : expr; field_name : ident; field_idx : int }
  | TExp_FieldSet of {
      record : expr;
      field_name : ident;
      field_idx : int;
      value : expr;
    }

and pattern_case = {
  id : int;
  pattern : pattern;
  when_condition : expr option;
  body : expr;
  loc : location;
  ty : ty;
}

and pattern = { id : int; pattern_desc : pattern_desc; loc : location; ty : ty }

and pattern_record_field = {
  name : ident;
  field_idx : int;
  pattern : pattern option;
  loc : location;
}
(** A single field in a typed record pattern. *)

(** The description of a typed pattern. *)
and pattern_desc =
  | TPat_Unit
  | TPat_BoolLit of string
  | TPat_IntLit of string
  | TPat_CharLit of string
  | TPat_StringLit of string
  | TPat_FloatLit of string
  | TPat_Ident of ident
  | TPat_Tuple of { elements : pattern list }
  | TPat_Record of { fields : pattern_record_field list }
  | TPat_Constructor of { tag : int; ident : string; pattern : pattern option }
  | TPat_Any

(** Description of a typed signature item. *)
type signature_item_desc =
  | TSig_Value of { name : ident; ty : ty }
  | TSig_External of { fname : ident; ty : ty; external_fn : external_fn }
  | TSig_Type of ty_decl
  | TSig_ModuleSignature of module_signature

and symbol = { name : string; loc : location }

and external_fn = {
  symbol : symbol;
  kind : external_kind;
  calling_convention : string option (* e.g., "ccc", "fastcc", etc. *);
}
(** An FFI external function declaration. *)

and external_kind = Foreign | Primitive

and signature_item = {
  id : int;
  signature_item_desc : signature_item_desc;
  loc : location;
}
(** A signature item with ID and location. *)

(** Description of a typed structure item. *)
and structure_item_desc =
  | TStr_External of { fname : ident; ty : ty; external_fn : external_fn }
  | TStr_Let of letdef
  | TStr_Type of ty_decl
  | TStr_ModuleStructure of module_structure
  | TStr_ModuleSignature of module_signature

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
