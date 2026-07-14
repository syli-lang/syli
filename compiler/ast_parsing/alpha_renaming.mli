(** This module provides alpha-renaming for the parsed AST, replacing variable
    names with unique identifiers to avoid shadowing. *)

module RenameEnv : sig
  type t

  val empty : t
  val lookup : t -> string -> string
  val fresh_var : string -> string
  val extend : string -> t -> t * string
end

val bind_pattern : RenameEnv.t -> Ast.pattern -> RenameEnv.t * Ast.pattern
val rename_pattern_uses : RenameEnv.t -> Ast.pattern -> Ast.pattern

val rename_params :
  RenameEnv.t -> Ast.param list -> RenameEnv.t * Ast.param list

val rename_transformer : RenameEnv.t Ast_transformer_acc.transformer

type alpha_renamed_program = {
  env : RenameEnv.t;
  prog : Ast.structure_item list;
}

val run : Ast.structure_item list -> alpha_renamed_program
