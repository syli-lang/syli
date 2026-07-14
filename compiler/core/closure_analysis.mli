(** This module performs closure analysis on the core AST. It identifies free
    variables, lambda expressions, and classifies them as closures or normal
    functions. *)

open Syli_common

(** Module for comparing free variables (core identifiers). *)
module FreeVar : sig
  type t = Core_ast.ident

  val compare : Core_ast.ident -> Core_ast.ident -> int
end

module VarIdSet : Set.S with type elt = FreeVar.t
(** Set of free variable identifiers. *)

type closure_info = {
  id : int;
  free_vars : VarIdSet.t;
  lambda : Core_ast.lambda;
  is_from_arg : bool;
  arity : int;
}
(** Information about a single closure. *)

type core_closure_analysis = { closure_infos : (int, closure_info) Hashtbl.t }
(** Result of core AST closure analysis. *)

type visitor_ctx = {
  current_lambda_id : int option;
  local_names : StringSet.t;
  global_names : StringSet.t;
  lambda_info : (int, closure_info) Hashtbl.t;
  known_functions : int StringMap.t;
  lambda_arg_ids : (int, unit) Hashtbl.t;
}
(** Visitor context for closure analysis. *)

val push_free_var : visitor_ctx -> Core_ast.ident -> unit
(** Adds an identifier to the free variable set of the currently analyzed
    lambda. *)

val collect_global_names : Core_ast.module_core -> StringSet.t
(** Scans the module for top-level and externally-defined names to distinguish
    them from free variables during analysis. *)

val collect_known_functions : Core_ast.module_core -> int StringMap.t
(** Builds a map from lambda expression ID to function name for all known
    top-level and let-bound functions. *)

val run : Core_ast.module_core -> core_closure_analysis
(** Runs closure analysis on a core module. *)
