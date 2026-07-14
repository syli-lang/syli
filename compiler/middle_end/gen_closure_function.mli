val partial_closure_accum_dispatch_name :
  stored_args_size:int -> args_size:int -> ret_ty:Syli_ir.Oir.ty -> string

val build_partial_closure_accum_dispatch :
  stored_args_size:int ->
  args_size:int ->
  Syli_ir.Oir.ty ->
  Syli_ir.Oir.function_oir

val partial_closure_accum_name :
  stored_args_size:int -> args_size:int -> ret_ty:Syli_ir.Oir.ty -> string

val build_partial_closure_accum :
  stored_args_size:int ->
  args_size:int ->
  Syli_ir.Oir.ty ->
  Syli_ir.Oir.function_oir

val apply_wrapper_name :
  fn_name:string ->
  param_tys:Syli_ir.Oir.ty list ->
  ret_ty:Syli_ir.Oir.ty ->
  string

val build_apply_wrapper :
  fn_name:string ->
  param_tys:Syli_ir.Oir.ty list ->
  ret_ty:Syli_ir.Oir.ty ->
  Syli_ir.Oir.function_oir

val apply_wrapper_name_cast :
  fn_name:string ->
  param_tys:Syli_ir.Oir.ty list ->
  cast_from:Syli_ir.Oir.ty ->
  string

val build_apply_wrapper_cast :
  fn_name:string ->
  param_tys:Syli_ir.Oir.ty list ->
  cast_from:Syli_ir.Oir.ty ->
  Syli_ir.Oir.function_oir

val make_closure_accum_dispatch_name : int -> ret_ty:Syli_ir.Oir.ty -> string

val make_closure_accum_name :
  fn_name:string -> int -> ret_ty:Syli_ir.Oir.ty -> string

val build_make_closure_accum_dispatch :
  stored_args_size:int ->
  args_size:int ->
  specializations:(int * string * Syli_ir.Oir.ty list * Syli_ir.Oir.ty) list ->
  ret_ty:Syli_ir.Oir.ty ->
  int ->
  Syli_ir.Oir.function_oir

val build_make_closure_accum :
  fn_name:string ->
  stored_args_size:int ->
  args_size:int ->
  specializations:Syli_ir.Oir.ty list ->
  ret_ty:Syli_ir.Oir.ty ->
  int ->
  Syli_ir.Oir.function_oir
