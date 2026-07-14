(** Control flow graph analysis and construction for OIR blocks.

    Builds CFGs from OIR blocks and provides traversal orders. *)

open Syli_common

type cfg = { succ : int list IntMap.t; pred : int list IntMap.t }

val build_cfg : Oir.block list -> cfg
val build_block_map : Oir.block list -> Oir.block IntMap.t
val get_succ : cfg -> int -> int list
val get_pred : cfg -> int -> int list
val compute_rpo : cfg -> int -> int list
val compute_rpo_back : cfg -> int -> int list
val compute_bfs : cfg -> int -> int list
val compute_dfs : cfg -> int -> int list
val compute_linear : Oir.block list -> int list

type cfg_order =
  | ReversePostorder
  | ReversePostorderBack
  | BreadthFirst
  | DepthFirst
  | Linear

val get_block_order : cfg_order -> cfg -> int -> Oir.block list -> int list
