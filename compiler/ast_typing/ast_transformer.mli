(** This module provides a non-accumulating AST transformer for the typed AST.
    Each function transforms a node and returns a modified copy. *)

type transformer = {
  ty : transformer -> Typed_ast.ty -> Typed_ast.ty;
  expr : transformer -> Typed_ast.expr -> Typed_ast.expr;
  pattern : transformer -> Typed_ast.pattern -> Typed_ast.pattern;
  pattern_case :
    transformer -> Typed_ast.pattern_case -> Typed_ast.pattern_case;
  structure_item :
    transformer -> Typed_ast.structure_item -> Typed_ast.structure_item;
  signature_item :
    transformer -> Typed_ast.signature_item -> Typed_ast.signature_item;
  module_signature :
    transformer -> Typed_ast.module_signature -> Typed_ast.module_signature;
  module_structure :
    transformer -> Typed_ast.module_structure -> Typed_ast.module_structure;
}

val transform_ty : transformer -> Typed_ast.ty -> Typed_ast.ty
val transform_pattern : transformer -> Typed_ast.pattern -> Typed_ast.pattern
val transform_param : transformer -> Typed_ast.param -> Typed_ast.param
val transform_lambda : transformer -> Typed_ast.lambda -> Typed_ast.lambda
val transform_letdef : transformer -> Typed_ast.letdef -> Typed_ast.letdef
val transform_expr : transformer -> Typed_ast.expr -> Typed_ast.expr

val transform_pattern_case :
  transformer -> Typed_ast.pattern_case -> Typed_ast.pattern_case

val transform_ty_decl : transformer -> Typed_ast.ty_decl -> Typed_ast.ty_decl

val transform_signature_item :
  transformer -> Typed_ast.signature_item -> Typed_ast.signature_item

val transform_structure_item :
  transformer -> Typed_ast.structure_item -> Typed_ast.structure_item

val transform_module_signature :
  transformer -> Typed_ast.module_signature -> Typed_ast.module_signature

val transform_module_structure :
  transformer -> Typed_ast.module_structure -> Typed_ast.module_structure

val default_ty : transformer -> Typed_ast.ty -> Typed_ast.ty
val default_expr : transformer -> Typed_ast.expr -> Typed_ast.expr
val default_pattern : transformer -> Typed_ast.pattern -> Typed_ast.pattern

val default_pattern_case :
  transformer -> Typed_ast.pattern_case -> Typed_ast.pattern_case

val default_structure_item :
  transformer -> Typed_ast.structure_item -> Typed_ast.structure_item

val default_signature_item :
  transformer -> Typed_ast.signature_item -> Typed_ast.signature_item

val default_module_signature :
  transformer -> Typed_ast.module_signature -> Typed_ast.module_signature

val default_module_structure :
  transformer -> Typed_ast.module_structure -> Typed_ast.module_structure

val identity_transformer : transformer
val apply_expr : transformer -> Typed_ast.expr -> Typed_ast.expr
val apply_pattern : transformer -> Typed_ast.pattern -> Typed_ast.pattern
val apply_ty : transformer -> Typed_ast.ty -> Typed_ast.ty

val apply_pattern_case :
  transformer -> Typed_ast.pattern_case -> Typed_ast.pattern_case

val apply_structure_item :
  transformer -> Typed_ast.structure_item -> Typed_ast.structure_item

val apply_program :
  transformer -> Typed_ast.structure_item list -> Typed_ast.structure_item list
