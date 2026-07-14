(** This module provides an accumulating AST transformer for the typed AST. Each
    transformer function visits a node and threads an accumulator through the
    traversal. *)

type 'acc transformer = {
  ty : 'acc transformer -> 'acc -> Typed_ast.ty -> 'acc * Typed_ast.ty;
  expr : 'acc transformer -> 'acc -> Typed_ast.expr -> 'acc * Typed_ast.expr;
  pattern :
    'acc transformer -> 'acc -> Typed_ast.pattern -> 'acc * Typed_ast.pattern;
  pattern_case :
    'acc transformer ->
    'acc ->
    Typed_ast.pattern_case ->
    'acc * Typed_ast.pattern_case;
  structure_item :
    'acc transformer ->
    'acc ->
    Typed_ast.structure_item ->
    'acc * Typed_ast.structure_item;
  signature_item :
    'acc transformer ->
    'acc ->
    Typed_ast.signature_item ->
    'acc * Typed_ast.signature_item;
  module_signature :
    'acc transformer ->
    'acc ->
    Typed_ast.module_signature ->
    'acc * Typed_ast.module_signature;
  module_structure :
    'acc transformer ->
    'acc ->
    Typed_ast.module_structure ->
    'acc * Typed_ast.module_structure;
}

val transform_ty :
  'acc transformer -> 'acc -> Typed_ast.ty -> 'acc * Typed_ast.ty

val transform_pattern :
  'acc transformer -> 'acc -> Typed_ast.pattern -> 'acc * Typed_ast.pattern

val transform_param :
  'acc transformer -> 'acc -> Typed_ast.param -> 'acc * Typed_ast.param

val transform_lambda :
  'acc transformer -> 'acc -> Typed_ast.lambda -> 'acc * Typed_ast.lambda

val transform_letdef :
  'acc transformer -> 'acc -> Typed_ast.letdef -> 'acc * Typed_ast.letdef

val transform_expr :
  'acc transformer -> 'acc -> Typed_ast.expr -> 'acc * Typed_ast.expr

val transform_pattern_case :
  'acc transformer ->
  'acc ->
  Typed_ast.pattern_case ->
  'acc * Typed_ast.pattern_case

val transform_ty_decl :
  'acc transformer -> 'acc -> Typed_ast.ty_decl -> 'acc * Typed_ast.ty_decl

val transform_signature_item :
  'acc transformer ->
  'acc ->
  Typed_ast.signature_item ->
  'acc * Typed_ast.signature_item

val transform_module_signature :
  'acc transformer ->
  'acc ->
  Typed_ast.module_signature ->
  'acc * Typed_ast.module_signature

val transform_structure_item :
  'acc transformer ->
  'acc ->
  Typed_ast.structure_item ->
  'acc * Typed_ast.structure_item

val transform_module_structure :
  'acc transformer ->
  'acc ->
  Typed_ast.module_structure ->
  'acc * Typed_ast.module_structure

val default_ty : 'acc transformer -> 'acc -> Typed_ast.ty -> 'acc * Typed_ast.ty

val default_expr :
  'acc transformer -> 'acc -> Typed_ast.expr -> 'acc * Typed_ast.expr

val default_pattern :
  'acc transformer -> 'acc -> Typed_ast.pattern -> 'acc * Typed_ast.pattern

val default_pattern_case :
  'acc transformer ->
  'acc ->
  Typed_ast.pattern_case ->
  'acc * Typed_ast.pattern_case

val default_structure_item :
  'acc transformer ->
  'acc ->
  Typed_ast.structure_item ->
  'acc * Typed_ast.structure_item

val default_signature_item :
  'acc transformer ->
  'acc ->
  Typed_ast.signature_item ->
  'acc * Typed_ast.signature_item

val default_module_signature :
  'acc transformer ->
  'acc ->
  Typed_ast.module_signature ->
  'acc * Typed_ast.module_signature

val default_module_structure :
  'acc transformer ->
  'acc ->
  Typed_ast.module_structure ->
  'acc * Typed_ast.module_structure

val identity_transformer : 'acc transformer

val apply_expr :
  'acc transformer -> 'acc -> Typed_ast.expr -> 'acc * Typed_ast.expr

val apply_pattern :
  'acc transformer -> 'acc -> Typed_ast.pattern -> 'acc * Typed_ast.pattern

val apply_ty : 'acc transformer -> 'acc -> Typed_ast.ty -> 'acc * Typed_ast.ty

val apply_pattern_case :
  'acc transformer ->
  'acc ->
  Typed_ast.pattern_case ->
  'acc * Typed_ast.pattern_case

val apply_structure_item :
  'acc transformer ->
  'acc ->
  Typed_ast.structure_item ->
  'acc * Typed_ast.structure_item

val apply_program :
  'acc transformer ->
  'acc ->
  Typed_ast.structure_item list ->
  'acc * Typed_ast.structure_item list
