(** LLVM low-level IR helper functions.

    Provides utilities for working with LLVM IR, including type conversions,
    instruction generation, and memory management. *)

val ty_of_operand : Types.operand -> Types.lltype
val i64 : int -> Types.operand
val i32 : int -> Types.operand
val i16 : int -> Types.operand
val i8 : int -> Types.operand
val i1 : bool -> Types.operand
val f32 : float -> Types.operand
val f64 : float -> Types.operand
val null : Types.lltype -> Types.operand
val zeroinitializer : Types.lltype -> Types.operand
val local : string -> Types.lltype -> Types.operand
val global : string -> Types.lltype -> Types.operand
val string_of_lltype : Types.lltype -> string
val string_of_float_literal : float -> string
val string_of_operand : Types.operand -> string
val string_of_typed_operand : Types.operand -> string
val string_of_ibinop : Types.ibinop -> string
val string_of_fbinop : Types.fbinop -> string
val string_of_icmp : Types.icmp_cond -> string
val string_of_fcmp : Types.fcmp_cond -> string
val string_of_cast_op : Types.cast_op -> string
val string_of_terminator : Types.terminator -> string
