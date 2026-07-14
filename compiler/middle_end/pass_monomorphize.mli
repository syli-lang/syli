(** Monomorphizes polymorphic functions by generating specialized versions at
    concrete call sites.

    Starts from concrete functions and recursively processes each new
    specialization. Filters out generic template functions and globals after
    specialization. *)

val monomorphize_program : Pipeline_types.cir_ctx -> Pipeline_types.cir_mono_ctx
