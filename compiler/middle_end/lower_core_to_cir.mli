(** Lowers the typed Core AST to SIR (the main lowering pass). *)

val lower : Pipeline_types.core_ctx -> Pipeline_types.cir_ctx
