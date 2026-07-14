(** This module provides record type utility functions for the type inference
    system: field lookup, candidate filtering, and compatibility checks. *)

val record_key_of_expr_fields : Typed_ast.record_field list -> string
(** Computes a structural record key from expression field names for record type
    disambiguation. *)

val find_record_field_decl_by_name :
  Typed_ast.record_field_decl list ->
  string ->
  Typed_ast.record_field_decl option
(** Searches a list of field declarations for one matching the given field name.
*)

val compatible_record_field_ty : Typed_ast.ty -> Typed_ast.ty -> bool
(** Checks whether two record field types can be unified (used during record
    type inference). *)

val filter_record_candidates :
  Env.ty_record_info list ->
  Typed_ast.record_field list ->
  Env.ty_record_info list
(** Narrows the list of candidate record types to those whose field names match
    the given expression fields. *)

val filter_record_candidates_by_field_type :
  Env.ty_record_info list -> Typed_ast.ty -> Env.ty_record_info list
(** Narrows record candidates to those containing a field of the specified type.
*)

val filter_record_candidates_by_expr_fields :
  Env.ty_record_info list ->
  Typed_ast.record_field list ->
  compatible:(Typed_ast.record_field_decl -> Typed_ast.record_field -> bool) ->
  Env.ty_record_info list
(** Narrows record candidates using expression fields and a caller- provided
    compatibility check on each field. *)

val filter_record_candidates_by_types :
  Env.infer_ctx ->
  Env.ty_record_info list ->
  Typed_ast.ty list ->
  Env.ty_record_info list
(** Narrows record candidates to those whose field types match the given list of
    expected types. *)

val field_index_of_record_ty :
  Env.infer_ctx -> Typed_ast.ty -> string -> (int * Typed_ast.ty) option
(** Resolves a record field name to its index and type within a record type,
    using the inference context for unification. *)
