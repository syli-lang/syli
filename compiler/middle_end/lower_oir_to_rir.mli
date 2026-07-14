(** Converts OIR to RIR (lower-level intermediate representation).

    Key transformations:
    - OIR types, operands, and variables are lowered to RIR counterparts
    - Object operations are lowered to runtime call helper functions
    - Control flow and basic structure are preserved *)

val lower : Pipeline_types.oir_ctx -> Pipeline_types.rir_ctx
