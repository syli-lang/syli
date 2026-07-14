(** This module defines the inference environment, type schemes, record type
    information, and the core inference context used throughout type-checking.
*)

open Syli_common

exception Type_error of string
(** Exception raised on type errors during inference. *)

type scheme = { vars : int list; body : Typed_ast.ty }
(** A type scheme (polymorphic type with quantified variables). *)

(** The type environment maps variable names to their type schemes. *)
module TyEnv : sig
  type t = scheme StringMap.t

  val empty : t
  (** The empty type environment. *)

  val extend : string -> scheme -> t -> t
  (** Binds a name to a scheme in the environment. *)

  val lookup_opt : string -> t -> scheme option
  (** Looks up a name in the environment, returning [None] if absent. *)

  val bindings : t -> (string * scheme) list
  (** Returns all bindings as an association list. *)
end

type ty_record_info = { ty_decl : Typed_ast.ty_decl; key : string }
(** Information about a record type used during inference. *)

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
(** Inference context with all maps initialized to empty. *)

val lookup_record_candidates : infer_ctx -> string -> ty_record_info list
(** Retrieves all record type definitions registered under the given structural
    key. *)

val record_key_of_field_names : string list -> string
(** Computes a structural record key by sorting and joining field names (used
    for record type disambiguation). *)

val record_key_of_record_decl_fields :
  Typed_ast.record_field_decl list -> string
(** Computes a structural record key from a list of typed record field
    declarations. *)

val register_ty_decl : infer_ctx -> Typed_ast.ty_decl -> infer_ctx
(** Adds a type declaration to the inference context, making it available for
    lookup by name and record key. *)

val lookup_ty_decl_by_name : infer_ctx -> string -> Typed_ast.ty_decl option
(** Finds a registered type declaration by its name. *)
