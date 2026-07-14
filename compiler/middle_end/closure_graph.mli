(** Closure_graph provides the closure call graph analysis for CIR. It analyzes
    function applications, partial applications, and closure creation to build a
    call graph used for code generation. *)

open Syli_common
open Syli_ir.Cir

type node_id = int

type node_kind =
  | NK_Make_closure
  | NK_Partial_apply
  | NK_Apply
  | NK_Arrow_move
  | NK_Arrow_cast

type node = {
  id : node_id;
  block_id : int;
  arg_tys : ty list;
  remaining_arg_tys : ty list;
  ret_ty : ty;
  node_kind : node_kind;
}

type root =
  | OR_Make_closure of qualified_name * node_id
  | OR_From_Arg_Fn of node_id

type summary = {
  root : root;
  acc_node_args : node_id list;
  ret_ty : ty;
  remaining_arg_tys : ty list;
  free_var_count : int;
}

type fn_specialization = {
  fn_name : qualified_name;
  arg_tys : ty list;
  ret_ty : ty;
  dispatch_cumul : int;
}

type graph = {
  nodes : node IntMap.t;
  node_summaries : summary list IntMap.t;
  edges : node_id list IntMap.t;
  heads : node_id list;
  root_ids : IntSet.t;
  node_leaf_summaries : summary list IntMap.t;
  node_roots : node_id list IntMap.t;
  closure_as_arg : IntSet.t;
}

type t = {
  graph : graph;
  closure_dispatch_ids : Closure_dispatch_id.t;
  node_dispatch_possibilities : int list IntMap.t;
  concrete_ret_ty : ty IntMap.t (* Not all nodes has concrete ret_ty *);
  make_closure_fn_specializations : fn_specialization list IntMap.t;
  generic_nodes : IntSet.t;
}
(** The closure call graph analysis. *)

val analyze : Syli_ir.Cir.module_cir -> t
(** Walks a CIR module to construct the full closure call graph. *)

val dispatch_edge_weight : t -> src:node_id -> target:node_id -> int
(** Get the dispatch edge weight between two nodes. *)

val get_node_dispatch_possibilities : t -> node_id -> int list
(** Get the dispatch possibilities for a given node. *)
