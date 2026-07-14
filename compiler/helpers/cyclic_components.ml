module Make (Node : Graph.NODE) = struct
  module Graph = Graph.Make (Node)
  include Graph

  (* First pass: compute finish order *)
  let dfs_finish_order graph =
    let visited = ref empty in
    let order = ref [] in
    let rec dfs v =
      if not (mem_node v !visited) then (
        visited := add_node v !visited;
        List.iter dfs (NodeSet.elements (successors v graph));
        order := v :: !order)
    in
    iter_nodes dfs graph;
    !order

  (* Second pass: collect components *)
  let kosaraju_scc graph =
    let order = dfs_finish_order graph in
    let rev_graph = reverse graph in
    let visited = ref empty in
    let rec dfs_collect v acc =
      if mem_node v !visited then acc
      else (
        visited := add_node v !visited;
        List.fold_left
          (fun acc w -> dfs_collect w acc)
          (v :: acc)
          (NodeSet.elements (successors v rev_graph)))
    in
    let components = ref [] in
    List.iter
      (fun v ->
        if not (mem_node v !visited) then
          let comp = dfs_collect v [] in
          components := comp :: !components)
      order;
    List.rev !components

  let cyclic_components graph =
    kosaraju_scc graph
    |> List.filter (function
      | [] -> false
      | [ n ] ->
          List.exists
            (fun s -> Node.compare s n = 0)
            (NodeSet.elements (successors n graph))
      | _ -> true)
end
