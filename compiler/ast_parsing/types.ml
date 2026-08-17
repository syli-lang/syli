type path = string list (* ["Std"; "List"] *)

(* Source location *)
type location = { start_pos : int; end_pos : int; filename : string }
type ident = { name : string; path : path; id : int; loc : location }
type mut_flag = Mutable | Immutable

(* ========================= *)
(* Constants *)
(* ========================= *)

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
  | Ty_Float (* 32 bit *)
  | Ty_Double (* 64 bit *)
  | Ty_StringLit
  | Ty_CharLit

(* ========================= *)
(* Types *)
(* ========================= *)

type ty = { id : int; ty_desc : ty_desc; loc : location }

and ty_desc =
  | Ty_Var of { label : string; variable : int option }
    (* 'a with an optional unique variable id *)
  | Ty_Any (* _ *)
  | Ty_Constant of constant_ty
  | Ty_Arrow of ty list * ty (* (T1, T2, ...) -> T *)
  | Ty_Tuple of ty list (* (T1 * T2 * ... * Tn) *)
  | Ty_Array of ty (* array<T> *)
  | Ty_Ref of ty (* ref<T> *)
  | Ty_Defined of { name : ident; (* ref, option, list, etc. *) args : ty list }

(*===========================*)
(* Record Fields *)
(*===========================*)

type record_field_decl = {
  id : int;
  field_name : ident;
  field_ty : ty;
  field_mut : mut_flag;
  loc : location;
}

(* ========================= *)
(* Variant Constructors *)
(* ========================= *)

type variant_constructor_decl = {
  id : int;
  name : ident;
  arg :
    variant_constructor_arg
    option (* None = no argument, Some t = with an argument *);
  loc : location;
}

and variant_constructor_arg =
  | Constr_ty of ty
  | Constr_record of record_field_decl list

(* ========================= *)
(* Type Declarations *)
(* ========================= *)

type ty_decl_desc =
  | Tydef_Alias of ty
  | Tydef_Record of record_field_decl list (* Only nominal type for record *)
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
