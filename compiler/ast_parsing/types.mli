type path = string list
(** A dotted path of module names. *)

type location = { start_pos : int; end_pos : int; filename : string }
(** Source location in the input file. *)

type ident = { name : string; path : path; id : int; loc : location }
(** A name paired with a path, a unique ID and source location. *)

(** Mutability flag for let-bindings and record fields. *)
type mut_flag = Mutable | Immutable

(** Primitive constant types available in the language. *)
type constant_ty =
  | Ty_Int64
  | Ty_Int32
  | Ty_Int16
  | Ty_Int8
  | Ty_UInt64
  | Ty_UInt32
  | Ty_UInt16
  | Ty_UInt8
  | Ty_Bool
  | Ty_Unit
  | Ty_Float
  | Ty_Double
  | Ty_StringLit
  | Ty_CharLit

type ty = { id : int; ty_desc : ty_desc; loc : location }
(** A type node with an ID and description. *)

(** The description of a type. *)
and ty_desc =
  | Ty_Var of { label : string; variable : int option }
  | Ty_Any
  | Ty_Constant of constant_ty
  | Ty_Arrow of ty list * ty
  | Ty_Tuple of ty list
  | Ty_Array of ty
  | Ty_Ref of ty
  | Ty_Defined of { name : ident; args : ty list }

type record_field_decl = {
  id : int;
  field_name : ident;
  field_ty : ty;
  field_mut : mut_flag;
  loc : location;
}
(** A single record field declaration. *)

type variant_constructor_decl = {
  id : int;
  name : ident;
  arg : variant_constructor_arg option;
  loc : location;
}
(** A single variant constructor declaration. *)

and variant_constructor_arg =
  | Constr_ty of ty
  | Constr_record of record_field_decl list

(** The body of a type declaration. *)
type ty_decl_desc =
  | Tydef_Alias of ty
  | Tydef_Record of record_field_decl list
  | Tydef_Variant of variant_constructor_decl list
  | Tydef_Abstract

type ty_decl = {
  id : int;
  name : ident;
  params : string list;
  def : ty_decl_desc;
  annotations : ident list;
  loc : location;
}
(** A type declaration (alias, record, variant, or abstract). *)
