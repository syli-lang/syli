(** This module provides a visitor for the core AST. Visitor functions traverse
    children without modifying nodes and thread an accumulator. *)

type 'acc visitor = {
  ty : 'acc visitor -> 'acc -> Core_ast.ty -> 'acc;
  expr : 'acc visitor -> 'acc -> Core_ast.expr -> 'acc;
  structure_item : 'acc visitor -> 'acc -> Core_ast.structure_item -> 'acc;
  signature_item : 'acc visitor -> 'acc -> Core_ast.signature_item -> 'acc;
  type_decl : 'acc visitor -> 'acc -> Core_ast.ty_decl -> 'acc;
}

val visit_ty_children : 'acc visitor -> 'acc -> Core_ast.ty -> 'acc
val visit_lambda : 'acc visitor -> 'acc -> Core_ast.lambda -> 'acc
val visit_expr_children : 'acc visitor -> 'acc -> Core_ast.expr -> 'acc
val visit_type_decl_children : 'acc visitor -> 'acc -> Core_ast.ty_decl -> 'acc

val visit_signature_item_children :
  'acc visitor -> 'acc -> Core_ast.signature_item -> 'acc

val visit_structure_item_children :
  'acc visitor -> 'acc -> Core_ast.structure_item -> 'acc

val default_ty : 'acc visitor -> 'acc -> Core_ast.ty -> 'acc
val default_expr : 'acc visitor -> 'acc -> Core_ast.expr -> 'acc

val default_structure_item :
  'acc visitor -> 'acc -> Core_ast.structure_item -> 'acc

val default_signature_item :
  'acc visitor -> 'acc -> Core_ast.signature_item -> 'acc

val default_type_decl : 'acc visitor -> 'acc -> Core_ast.ty_decl -> 'acc
val identity_visitor : 'acc visitor
val default_visitor : 'a visitor
val visit_ty : 'acc visitor -> 'acc -> Core_ast.ty -> 'acc
val visit_expr : 'acc visitor -> 'acc -> Core_ast.expr -> 'acc

val visit_structure_item :
  'acc visitor -> 'acc -> Core_ast.structure_item -> 'acc

val visit_signature_item :
  'acc visitor -> 'acc -> Core_ast.signature_item -> 'acc

val visit_type_decl : 'acc visitor -> 'acc -> Core_ast.ty_decl -> 'acc
val visit_program : 'acc visitor -> 'acc -> Core_ast.module_core -> 'acc
val collect_idents : Core_ast.module_core -> string list
val collect_function_names : Core_ast.module_core -> string list
val collect_type_defs : Core_ast.module_core -> (string * Core_ast.ty_decl) list
val count_expr_nodes : Core_ast.module_core -> int
