(** LLVM code generation backend.

    Converts RIR to LLVM IR, producing a textual `.ll` representation that can
    be compiled by `llc` or linked by the system linker. *)

module Rir = Syli_ir.Rir

val lower_program : Rir.program_rir -> Llvm_lir.module_
val lower : Rir.program_rir -> Llvm_lir.module_
val to_string : Rir.program_rir -> string
