(** Pretty printing for SIR.

    Provides human-readable string representations for all SIR constructs,
    useful for debugging and compiler output. *)

val string_of_ty : Cir.ty -> string
val string_of_program : Cir.module_cir -> string
