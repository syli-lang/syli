(** This module defines the inference environment, type schemes, record type
    information, and the core inference context used throughout type-checking.
*)

open Syli_common
open Typed_ast

exception Type_error of string

type scheme = { vars : int list; body : Typed_ast.ty }
(** A type scheme (polymorphic type with quantified variables). *)

(** The type environment maps variable names to their type schemes. *)
module TyEnv : sig
  type t = scheme StringMap.t

  val empty : t

  val extend : string -> scheme -> t -> t
  (** Binds a name to a scheme in the environment. *)

  val lookup_opt : string -> t -> scheme option
  (** Looks up a name in the environment, returning [None] if absent. *)

  val bindings : t -> (string * scheme) list
  (** Returns all bindings as an association list. *)
end

type ty_record_info = {
  record_fields : record_field_decl list;
  ty_decl : ty_decl;
}

type infer_ctx = {
  env : TyEnv.t;
  subst : Subst.t;
  return_ty : Typed_ast.ty option;
  break_ty : Typed_ast.ty option;
  record_env : ty_record_info list StringMap.t;
  ty_name_env : Typed_ast.ty_decl StringMap.t;
}
(** The full inference context, threading environment, substitution, and other
    state through the type-checker. *)

val empty_ctx : infer_ctx

val register_ty_decl : infer_ctx -> Typed_ast.ty_decl -> infer_ctx
(** Adds a type declaration to the inference context, making it available for
    lookup by name *)

val find_record_by_field_names :
  infer_ctx -> string list -> ty_record_info option
