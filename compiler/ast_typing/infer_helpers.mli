(** This module provides helper functions for the type inference engine: fresh
    type variable generation, scheme instantiation, and parameter matching. *)

val fresh_ty : Env.infer_ctx -> Env.infer_ctx * Typed_ast.ty

val matching_param_to_arg :
  'a list -> 'b list -> 'a list * 'b list * 'a list * 'b list

val instantiate_scheme :
  Env.infer_ctx -> Env.scheme -> Env.infer_ctx * Typed_ast.ty
