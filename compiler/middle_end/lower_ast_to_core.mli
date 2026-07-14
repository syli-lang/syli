(** Desugars the typed AST into the Core AST representation.

    Translates higher-level typed constructs (match, while, for, lambda, etc.)
    into the simpler Core AST form used by the rest of the compiler pipeline. *)

module Typed_ast = Syli_typing.Typed_ast

val lower : Typed_ast.module_structure -> Syli_core.Core_ast.module_core
