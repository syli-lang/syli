(** This module provides a visitor for the typed AST. Visitor functions traverse
    children without modifying nodes and thread an accumulator. *)

type 'acc visitor = {
  ty : 'acc visitor -> 'acc -> Typed_ast.ty -> 'acc;
  expr : 'acc visitor -> 'acc -> Typed_ast.expr -> 'acc;
  pattern : 'acc visitor -> 'acc -> Typed_ast.pattern -> 'acc;
  pattern_case : 'acc visitor -> 'acc -> Typed_ast.pattern_case -> 'acc;
  structure_item : 'acc visitor -> 'acc -> Typed_ast.structure_item -> 'acc;
  signature_item : 'acc visitor -> 'acc -> Typed_ast.signature_item -> 'acc;
  module_signature : 'acc visitor -> 'acc -> Typed_ast.module_signature -> 'acc;
  module_structure : 'acc visitor -> 'acc -> Typed_ast.module_structure -> 'acc;
}

val visit_ty_children : 'acc visitor -> 'acc -> Typed_ast.ty -> 'acc
val visit_pattern_children : 'acc visitor -> 'acc -> Typed_ast.pattern -> 'acc
val visit_param : 'acc visitor -> 'acc -> Typed_ast.param -> 'acc
val visit_lambda : 'acc visitor -> 'acc -> Typed_ast.lambda -> 'acc
val visit_letdef : 'acc visitor -> 'acc -> Typed_ast.letdef -> 'acc
val visit_expr_children : 'acc visitor -> 'acc -> Typed_ast.expr -> 'acc

val visit_pattern_case_children :
  'acc visitor -> 'acc -> Typed_ast.pattern_case -> 'acc

val visit_ty_decl : 'acc visitor -> 'acc -> Typed_ast.ty_decl -> 'acc

val visit_signature_item_children :
  'acc visitor -> 'acc -> Typed_ast.signature_item -> 'acc

val visit_module_signature_children :
  'acc visitor -> 'acc -> Typed_ast.module_signature -> 'acc

val visit_structure_item_children :
  'acc visitor -> 'acc -> Typed_ast.structure_item -> 'acc

val visit_module_structure_children :
  'acc visitor -> 'acc -> Typed_ast.module_structure -> 'acc

val default_ty : 'acc visitor -> 'acc -> Typed_ast.ty -> 'acc
val default_expr : 'acc visitor -> 'acc -> Typed_ast.expr -> 'acc
val default_pattern : 'acc visitor -> 'acc -> Typed_ast.pattern -> 'acc

val default_pattern_case :
  'acc visitor -> 'acc -> Typed_ast.pattern_case -> 'acc

val default_structure_item :
  'acc visitor -> 'acc -> Typed_ast.structure_item -> 'acc

val default_signature_item :
  'acc visitor -> 'acc -> Typed_ast.signature_item -> 'acc

val default_module_signature :
  'acc visitor -> 'acc -> Typed_ast.module_signature -> 'acc

val default_module_structure :
  'acc visitor -> 'acc -> Typed_ast.module_structure -> 'acc

val identity_visitor : 'acc visitor
val default_visitor : 'a visitor
val visit_expr : 'acc visitor -> 'acc -> Typed_ast.expr -> 'acc
val visit_pattern : 'acc visitor -> 'acc -> Typed_ast.pattern -> 'acc
val visit_ty : 'acc visitor -> 'acc -> Typed_ast.ty -> 'acc
val visit_pattern_case : 'acc visitor -> 'acc -> Typed_ast.pattern_case -> 'acc

val visit_structure_item :
  'acc visitor -> 'acc -> Typed_ast.structure_item -> 'acc

val visit_program :
  'acc visitor -> 'acc -> Typed_ast.structure_item list -> 'acc
