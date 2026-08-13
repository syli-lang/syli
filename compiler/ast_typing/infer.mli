(** This module provides the main type inference engine for the parsed AST. *)

val infer_program :
  Syli_parsing.Ast.module_structure ->
  Env.infer_ctx * Typed_ast.module_structure
(** Entry point for type inference: type-checks an entire program from parse AST
    to typed AST. *)
