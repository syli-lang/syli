(** This module provides a functor-based directed graph data structure with
    adjacency list representation. *)

module type NODE = sig
  type t

  val compare : t -> t -> int
end

module Make : (Node : NODE) -> sig
  module NodeMap : Map.S with type key = Node.t
  module NodeSet : Set.S with type elt = Node.t

  type t

  val empty : t
  val add_node : Node.t -> t -> t
  val mem_node : Node.t -> t -> bool
  val iter_nodes : (Node.t -> unit) -> t -> unit
  val add_edge : src:Node.t -> target:Node.t -> t -> t
  val successors : Node.t -> t -> NodeSet.t
  val reverse : t -> t
end
