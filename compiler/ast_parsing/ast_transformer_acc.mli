(** This module provides an accumulating AST transformer for the parse AST. Each
    transformer function visits a node and threads an accumulator through the
    traversal. *)

type 'acc transformer = {
  ty : 'acc transformer -> 'acc -> Ast.ty -> 'acc * Ast.ty;
  expr : 'acc transformer -> 'acc -> Ast.expr -> 'acc * Ast.expr;
  pattern : 'acc transformer -> 'acc -> Ast.pattern -> 'acc * Ast.pattern;
  pattern_case :
    'acc transformer -> 'acc -> Ast.pattern_case -> 'acc * Ast.pattern_case;
  structure_item :
    'acc transformer -> 'acc -> Ast.structure_item -> 'acc * Ast.structure_item;
  signature_item :
    'acc transformer -> 'acc -> Ast.signature_item -> 'acc * Ast.signature_item;
  module_signature :
    'acc transformer ->
    'acc ->
    Ast.module_signature ->
    'acc * Ast.module_signature;
  module_structure :
    'acc transformer ->
    'acc ->
    Ast.module_structure ->
    'acc * Ast.module_structure;
}

val transform_ty : 'acc transformer -> 'acc -> Ast.ty -> 'acc * Ast.ty

val transform_pattern :
  'acc transformer -> 'acc -> Ast.pattern -> 'acc * Ast.pattern

val transform_param : 'acc transformer -> 'acc -> Ast.param -> 'acc * Ast.param

val transform_lambda :
  'acc transformer -> 'acc -> Ast.lambda -> 'acc * Ast.lambda

val transform_letdef :
  'acc transformer -> 'acc -> Ast.letdef -> 'acc * Ast.letdef

val transform_expr : 'acc transformer -> 'acc -> Ast.expr -> 'acc * Ast.expr

val transform_pattern_case :
  'acc transformer -> 'acc -> Ast.pattern_case -> 'acc * Ast.pattern_case

val transform_ty_decl :
  'acc transformer -> 'acc -> Ast.ty_decl -> 'acc * Ast.ty_decl

val transform_signature_item :
  'acc transformer -> 'acc -> Ast.signature_item -> 'acc * Ast.signature_item

val transform_module_signature :
  'acc transformer ->
  'acc ->
  Ast.module_signature ->
  'acc * Ast.module_signature

val transform_structure_item :
  'acc transformer -> 'acc -> Ast.structure_item -> 'acc * Ast.structure_item

val transform_module_structure :
  'acc transformer ->
  'acc ->
  Ast.module_structure ->
  'acc * Ast.module_structure

val default_ty : 'acc transformer -> 'acc -> Ast.ty -> 'acc * Ast.ty
val default_expr : 'acc transformer -> 'acc -> Ast.expr -> 'acc * Ast.expr

val default_pattern :
  'acc transformer -> 'acc -> Ast.pattern -> 'acc * Ast.pattern

val default_pattern_case :
  'acc transformer -> 'acc -> Ast.pattern_case -> 'acc * Ast.pattern_case

val default_structure_item :
  'acc transformer -> 'acc -> Ast.structure_item -> 'acc * Ast.structure_item

val default_signature_item :
  'acc transformer -> 'acc -> Ast.signature_item -> 'acc * Ast.signature_item

val default_module_signature :
  'acc transformer ->
  'acc ->
  Ast.module_signature ->
  'acc * Ast.module_signature

val default_module_structure :
  'acc transformer ->
  'acc ->
  Ast.module_structure ->
  'acc * Ast.module_structure

val identity_transformer : 'acc transformer
val apply_expr : 'acc transformer -> 'acc -> Ast.expr -> 'acc * Ast.expr

val apply_pattern :
  'acc transformer -> 'acc -> Ast.pattern -> 'acc * Ast.pattern

val apply_ty : 'acc transformer -> 'acc -> Ast.ty -> 'acc * Ast.ty

val apply_pattern_case :
  'acc transformer -> 'acc -> Ast.pattern_case -> 'acc * Ast.pattern_case

val apply_structure_item :
  'acc transformer -> 'acc -> Ast.structure_item -> 'acc * Ast.structure_item

val apply_program :
  'acc transformer ->
  'acc ->
  Ast.structure_item list ->
  'acc * Ast.structure_item list

val transform_expr : 'a transformer -> 'a -> Ast.expr -> 'a * Ast.expr
val transform_pattern : 'a transformer -> 'a -> Ast.pattern -> 'a * Ast.pattern

val transform_structure_item :
  'a transformer -> 'a -> Ast.structure_item -> 'a * Ast.structure_item

val transform_pattern_case :
  'a transformer -> 'a -> Ast.pattern_case -> 'a * Ast.pattern_case
