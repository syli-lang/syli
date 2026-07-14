(** This module provides pretty-printing functions for the typed AST, converting
    nodes back to human-readable string representations. *)

val indent : int -> string
val string_of_ty : Typed_ast.ty -> string
val string_of_unop : Typed_ast.unop -> string
val string_of_binop : Typed_ast.binop -> string
val string_of_pattern : Typed_ast.pattern -> string
val string_of_constant : Typed_ast.constant -> string
val string_of_expr : ?ind:int -> Typed_ast.expr -> string
