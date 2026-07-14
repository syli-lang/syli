(** This module performs post-typing analysis: path collection and field index
    resolution on the typed AST. *)

module IdentEnv : sig
  type t

  val empty : t
  val lookup : t -> string -> string
  val add : string -> string -> t -> t
end

type path_ctx = {
  renameEnv : IdentEnv.t;
  collected_paths : (int, string) Hashtbl.t;
  current_path : string list;
}

val collect_paths : Typed_ast.module_structure -> path_ctx

type field_ctx = { field_indices : (int, int) Hashtbl.t }

val collect_field_indices : Typed_ast.module_structure -> field_ctx
