(** This module provides an accumulating AST transformer for the core AST. Each
    transformer function visits a node and threads an accumulator through the
    traversal. *)

type 'acc transformer = {
  ty : 'acc transformer -> 'acc -> Core_ast.ty -> 'acc * Core_ast.ty;
  expr : 'acc transformer -> 'acc -> Core_ast.expr -> 'acc * Core_ast.expr;
  structure_item :
    'acc transformer ->
    'acc ->
    Core_ast.structure_item ->
    'acc * Core_ast.structure_item;
  signature_item :
    'acc transformer ->
    'acc ->
    Core_ast.signature_item ->
    'acc * Core_ast.signature_item;
  type_decl :
    'acc transformer -> 'acc -> Core_ast.ty_decl -> 'acc * Core_ast.ty_decl;
}

val transform_ty : 'acc transformer -> 'acc -> Core_ast.ty -> 'acc * Core_ast.ty

val transform_lambda :
  'acc transformer -> 'acc -> Core_ast.lambda -> 'acc * Core_ast.lambda

val transform_expr :
  'acc transformer -> 'acc -> Core_ast.expr -> 'acc * Core_ast.expr

val transform_type_decl :
  'acc transformer -> 'acc -> Core_ast.ty_decl -> 'acc * Core_ast.ty_decl

val transform_signature_item :
  'acc transformer ->
  'acc ->
  Core_ast.signature_item ->
  'acc * Core_ast.signature_item

val transform_structure_item :
  'acc transformer ->
  'acc ->
  Core_ast.structure_item ->
  'acc * Core_ast.structure_item

val transform_program :
  'acc transformer ->
  'acc ->
  Core_ast.module_core ->
  'acc * Core_ast.module_core

val default_ty : 'acc transformer -> 'acc -> Core_ast.ty -> 'acc * Core_ast.ty

val default_expr :
  'acc transformer -> 'acc -> Core_ast.expr -> 'acc * Core_ast.expr

val default_structure_item :
  'acc transformer ->
  'acc ->
  Core_ast.structure_item ->
  'acc * Core_ast.structure_item

val default_signature_item :
  'acc transformer ->
  'acc ->
  Core_ast.signature_item ->
  'acc * Core_ast.signature_item

val default_type_decl :
  'acc transformer -> 'acc -> Core_ast.ty_decl -> 'acc * Core_ast.ty_decl

val identity_transformer : 'acc transformer
val apply_ty : 'acc transformer -> 'acc -> Core_ast.ty -> 'acc * Core_ast.ty

val apply_expr :
  'acc transformer -> 'acc -> Core_ast.expr -> 'acc * Core_ast.expr

val apply_structure_item :
  'acc transformer ->
  'acc ->
  Core_ast.structure_item ->
  'acc * Core_ast.structure_item

val apply_signature_item :
  'acc transformer ->
  'acc ->
  Core_ast.signature_item ->
  'acc * Core_ast.signature_item

val apply_type_decl :
  'acc transformer -> 'acc -> Core_ast.ty_decl -> 'acc * Core_ast.ty_decl

val apply_program :
  'acc transformer ->
  'acc ->
  Core_ast.module_core ->
  'acc * Core_ast.module_core
