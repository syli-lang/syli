(** Liveness analysis for reference-typed OIR variables (OR_Obj, OR_Ptr). Used
    by pass_rc_insertion to decide where reference-counting operations can be
    inserted. *)

open Syli_common

type live_info = { live_before : IntSet.t; live_after : IntSet.t }

type t = live_info IntMap.t
(** Keyed by [statement.id]. *)

val analyze : Syli_ir.Oir.function_oir -> t
(** Single-pass backward dataflow analysis. Relies on SSA property (each var
    defined once in a block) so no fixpoint iteration is needed. *)
