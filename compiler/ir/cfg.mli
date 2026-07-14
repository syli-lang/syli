(** Control flow graph analysis and construction.

    Builds CFGs from SIR blocks and provides traversal orders useful for
    optimization passes and analysis. *)

type cfg = {
  succ : (int, int list) Hashtbl.t;
  pred : (int, int list) Hashtbl.t;
}

val build_cfg : Cir.block list -> cfg
val build_block_map : Cir.block list -> (int, Cir.block) Hashtbl.t
val get_succ : cfg -> int -> int list
val get_pred : cfg -> int -> int list
val compute_rpo : cfg -> int -> int list
val compute_rpo_back : cfg -> int -> int list
val compute_bfs : cfg -> int -> int list
val compute_dfs : cfg -> int -> int list
val compute_linear : Cir.block list -> int list

type cfg_order =
  | ReversePostorder
  | ReversePostorderBack
  | BreadthFirst
  | DepthFirst
  | Linear

val get_block_order : cfg_order -> cfg -> int -> Cir.block list -> int list
