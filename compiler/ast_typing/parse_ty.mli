(** This module provides conversions from the parsed AST ([Syli_parsing.Ast]) to
    the typed AST ([Typed_ast]). *)

val const_ty_of_parsing : Syli_parsing.Ast.constant_ty -> Typed_ast.constant_ty
val loc_of_parsing : Syli_parsing.Ast.location -> Typed_ast.location
val ident_of_parsing : Syli_parsing.Ast.ident -> Typed_ast.ident
val mk_ty : Typed_ast.ty_desc -> Typed_ast.ty

val ty_of_parsing :
  Env.infer_ctx -> Syli_parsing.Ast.ty -> Env.infer_ctx * Typed_ast.ty

val constant_desc_of_parsing :
  Syli_parsing.Ast.constant_desc ->
  Typed_ast.constant_desc * Typed_ast.constant_ty

val unop_of_parsing : Syli_parsing.Ast.unop -> Typed_ast.unop
val binop_of_parsing : Syli_parsing.Ast.binop -> Typed_ast.binop
val field_mut_of_parsing : Syli_parsing.Ast.mut_flag -> Typed_ast.mut_flag

val ty_decl_of_parsing :
  Env.infer_ctx -> Syli_parsing.Ast.ty_decl -> Env.infer_ctx * Typed_ast.ty_decl

val external_fn_of_parsing :
  Typed_ast.location -> Syli_parsing.Ast.external_fn -> Typed_ast.external_fn

val signature_item_of_parsing :
  Env.infer_ctx ->
  Syli_parsing.Ast.signature_item ->
  Env.infer_ctx * Typed_ast.signature_item

val module_signature_of_parsing :
  Env.infer_ctx ->
  Syli_parsing.Ast.module_signature ->
  Env.infer_ctx * Typed_ast.module_signature
