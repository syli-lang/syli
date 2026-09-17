(** This module defines the core (normalized) AST types produced after
    type-checking and used by the middle-end passes. *)

val fresh_id : unit -> int
(** Returns a fresh unique integer ID. *)

type path = string list
(** A dotted path of module names. *)

type ident = { name : string; path : path; id : int }
(** An identifier with name, full name, path, unique ID, and [is_operator]. *)

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
  | CTy_F32
  | CTy_F64
  | CTy_String
  | CTy_Char

type ty = { ty_desc : ty_desc }
(** A type in the core AST. *)

(** The description of a core type. *)
and ty_desc =
  | CTy_Var of int
  | CTy_Constant of constant_ty
  | CTy_Arrow of ty * ty
  | CTy_Tuple of ty list
  | CTy_Array of ty
  | CTy_Defined of { name : ident; args : ty list }

and constructor_decl = { id : int; tag : int; arg : constructor_arg option }
(** A variant constructor declaration with tag number. *)

and constructor_arg =
  | Constr_ty of ty
  | Constr_record of record_field_ty list
      (** Argument of a variant constructor. *)

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

(* -------------------- *)
(* Expression AST       *)
(* -------------------- *)

type expr = { id : int; node : expr_node; ty : ty }
(** A core expression node. *)

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
  | CExp_Tuple of expr list
  | CExp_Record of record_field list
  | CExp_VariantConstructor of { tag : int; arg : expr option }
  | CExp_Array of { element_ty : ty; elements : expr list; size : expr }
  | CExp_Lambda of lambda
  | CExp_Apply of { closure_fun : expr; args : expr list }
  | CExp_Let of { rec_flag : rec_flag; name : ident; value : expr }
  | CExp_Loop of expr
  | CExp_Break of expr option
  | CExp_Continue
  | CExp_Return of expr option
  | CExp_Seq of expr list
  | CExp_If of {
      condition : expr;
      then_branch : expr;
      else_branch : expr option;
    }
  | CExp_Match of { expr : expr; cases : pattern_case list }
  | CExp_Field of { record : expr; field_idx : int }
  | CExp_FieldSet of { record : expr; field_idx : int; value : expr }

and pattern_case = {
  id : int;
  pattern : pattern;
  when_condition : expr option;
  body : expr;
}
(** A pattern-matching case in the core AST. *)

and pattern = { id : int; node : pattern_desc }
(** A core pattern node. *)

and pattern_record_field = { field_idx : int; pattern : pattern option }
(** A single field in a core record pattern. *)

(** The description of a core pattern. *)
and pattern_desc =
  | Pat_Unit
  | Pat_BoolLit of string
  | Pat_IntLit of string
  | Pat_CharLit of string
  | Pat_FloatLit of string
  | Pat_StringLit of string
  | Pat_Ident of ident
  | Pat_Record of pattern_record_field list
  | Pat_Tuple of pattern list
  | Pat_Constructor of { tag : int; pattern : pattern option }
  | Pat_Any

(*-------------------------------------*)
(* Module Core AST (Flattened)        *)
(*-------------------------------------*)
and external_fn = {
  symbol : string;
  kind : external_kind;
  calling_convention : string option (* e.g., "ccc", "fastcc", etc. *);
  public : bool;
}
(** An FFI external function declaration. *)

and external_kind = Foreign | Primitive

(** Description of a core structure item. *)
and structure_item_desc =
  | CStr_External of { fname : ident; ty : ty; external_fn : external_fn }
  | CStr_Let of {
      rec_flag : rec_flag;
      name : ident;
      value : expr;
      public : bool;
    }
  | CStr_Type of ty_decl

and structure_item = { id : int; structure_item_desc : structure_item_desc }
(** A structure item with ID. *)

and module_core = {
  id : int;
  name : ident;
  structure_items : structure_item list;
}
(** A complete core module with structure and signature items. *)

type program_core = module_core
(** A complete core program is a single module. *)
