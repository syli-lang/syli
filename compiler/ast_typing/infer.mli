(** This module provides the main type inference engine for the typed AST. It
    infers types for expressions, patterns, let-bindings, and top-level
    definitions. *)

module Parsing_ast = Syli_parsing.Ast

val apply_expr_ty : Env.infer_ctx -> Typed_ast.expr -> Typed_ast.expr
(** Substitutes all type variables in an expression's type annotation using the
    inference context's current substitution. *)

val apply_param_ty : Env.infer_ctx -> Typed_ast.param -> Typed_ast.param
(** Substitutes all type variables in a parameter's type annotation using the
    inference context's current substitution. *)

val unify_record_expr_fields_with_decl :
  Env.infer_ctx ->
  Typed_ast.record_field_decl list ->
  Typed_ast.record_field list ->
  Env.infer_ctx
(** Unifies each record expression field with the corresponding field
    declaration type, extending the inference context. *)

val infer_pattern :
  Env.infer_ctx -> Parsing_ast.pattern -> Env.infer_ctx * Typed_ast.pattern
(** Type-checks a parse-tree pattern, producing a typed pattern with inferred
    type. *)

val infer_expr :
  Env.infer_ctx -> Parsing_ast.expr -> Env.infer_ctx * Typed_ast.expr
(** Type-checks a parse-tree expression, producing a typed expression with
    inferred type. *)

val infer_letdef :
  Env.infer_ctx -> Parsing_ast.letdef -> Env.infer_ctx * Typed_ast.letdef
(** Type-checks a parse-tree let definition, extending the environment with the
    bound name. *)

val infer_structure_item :
  Env.infer_ctx ->
  Parsing_ast.structure_item ->
  Env.infer_ctx * Typed_ast.structure_item
(** Type-checks a structure item, extending the inference context with any new
    type or value definitions. *)

val infer_module_structure :
  Env.infer_ctx ->
  Parsing_ast.module_structure ->
  Env.infer_ctx * Typed_ast.module_structure
(** Type-checks all items in a module structure, accumulating type definitions
    and value bindings. *)

val validate_main : Typed_ast.module_structure -> unit
(** Validates that the program's main function has a valid entry-point signature
    (no parameters, returns unit). *)

val infer_program :
  Parsing_ast.module_structure -> Env.infer_ctx * Typed_ast.module_structure
(** Entry point for type inference: type-checks an entire program from parse AST
    to typed AST. *)
