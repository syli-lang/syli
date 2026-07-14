(** Prepares a compiled module for execution.

    Auto-generates the [syli_modules_init] and [syli_startup_program]
    scaffolding functions when a main entry point is found in the module. *)

val prepare_module : Pipeline_types.rir_ctx -> Pipeline_types.rir_ctx
