(** Conversion from CIR (Closure IR) to OIR (Object IR).

    Key transformations:
    - CR_Make_closure → object_create + field stores
    - CR_Partial_apply → object_create + field stores (chain via parent ptr)
    - Apply call target → Direct_fnptr (resolved to accum function)
    - CR_Arrow type → pointer type
    - CR_GenericTyp → error (should be monomorphized away) *)

val lower : Pipeline_types.cir_mono_ctx -> Pipeline_types.oir_ctx
