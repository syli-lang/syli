(** Compilation pipeline orchestration.

    Defines pipeline stages and the [run] function that compiles a source file
    through the requested stage, returning a string representation. *)

(** Supported pipeline output stages. *)
type t = Core | Cir_raw | Cir_mono | Cir | Oir | Rir | Llvm | Exec

val run : t -> string -> string
(** Run the pipeline up to stage [t] on [filename] and return the output. *)
