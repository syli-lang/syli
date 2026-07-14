module type NODE = sig
  type t

  val compare : t -> t -> int
end

module Make (Node : NODE) = struct
  module NodeMap = Map.Make (Node)
  module NodeSet = Set.Make (Node)

  type t = NodeSet.t NodeMap.t

  let empty : t = NodeMap.empty

  let add_node (node : Node.t) (graph : t) =
    if NodeMap.mem node graph then graph
    else NodeMap.add node NodeSet.empty graph

  let mem_node node graph : bool = NodeMap.mem node graph
  let iter_nodes f graph = NodeMap.iter (fun node _ -> f node) graph

  let add_edge ~(src : Node.t) ~(target : Node.t) (graph : t) : t =
    NodeMap.update src
      (fun x ->
        match x with
        | Some targets -> Option.some @@ NodeSet.add target targets
        | None -> Option.some @@ NodeSet.singleton target)
      graph

  let successors (node : Node.t) (graph : t) =
    match NodeMap.find_opt node graph with Some l -> l | None -> NodeSet.empty

  (* Reverse graph *)
  let reverse (graph : t) : t =
    NodeMap.fold
      (fun src targets acc ->
        NodeSet.fold
          (fun target acc -> add_edge ~src:target ~target:src acc)
          targets acc)
      graph empty
end
