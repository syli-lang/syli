(** Pretty printing for LLVM IR.

    Provides formatted output of LLVM IR structures for debugging and textual
    representation. *)

open Types

val instruction_to_string : int -> instruction -> string
val block_to_string : block -> string
val func_to_string : func -> string
val module_to_string : module_ -> string
