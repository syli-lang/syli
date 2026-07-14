(** This module provides alpha-renaming (variable normalization) for the typed
    core AST. It ensures that bound variable names are unique. *)

open Syli_common

module RenameEnv : sig
  type t = {
    map : string StringMap.t;
    toplevel_counts : int StringMap.t;
    toplevel_seen : int StringMap.t;
    counter : int ref;
  }

  val make_with_counts : int StringMap.t -> t
  val empty : t
  val lookup : t -> StringMap.key -> StringMap.key
  val fresh_var : t -> string -> string
  val extend : StringMap.key -> t -> t * StringMap.key
  val extend_toplevel : StringMap.key -> t -> t * StringMap.key
end

val count_toplevel_bindings : Core_ast.module_core -> int StringMap.t
val rename_ident_use : RenameEnv.t -> Core_ast.ident -> Core_ast.ident

val rename_lambda :
  RenameEnv.t Ast_transformer_acc.transformer ->
  RenameEnv.t ->
  Core_ast.lambda ->
  RenameEnv.t * Core_ast.lambda

val rename_transformer : RenameEnv.t Ast_transformer_acc.transformer

type renamed_program = { env : RenameEnv.t; prog : Core_ast.module_core }

val run_env : Core_ast.module_core -> renamed_program
val run : Core_ast.module_core -> Core_ast.module_core
