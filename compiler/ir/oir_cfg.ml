open Oir
open Syli_common

type cfg = { succ : int list IntMap.t; pred : int list IntMap.t }

let build_cfg (blocks : block list) : cfg =
  let init =
    List.fold_left
      (fun (succ, pred) (b : block) ->
        (IntMap.add b.id [] succ, IntMap.add b.id [] pred))
      (IntMap.empty, IntMap.empty)
      blocks
  in
  let succ, pred =
    List.fold_left
      (fun (succ, pred) (b : block) ->
        let successors =
          match b.terminator.node with
          | OR_Goto id -> [ id ]
          | OR_Switch { cases; default_block; _ } ->
              let case_targets = List.map (fun c -> c.target_block) cases in
              Option.to_list default_block @ case_targets
          | OR_CondBr { then_block; else_block; _ } ->
              [ then_block; else_block ]
          | OR_Return _ -> []
        in
        let succ = IntMap.add b.id successors succ in
        let pred =
          List.fold_left
            (fun pred sid ->
              let prev = try IntMap.find sid pred with Not_found -> [] in
              IntMap.add sid (b.id :: prev) pred)
            pred successors
        in
        (succ, pred))
      init blocks
  in
  { succ; pred }

let build_block_map (blocks : block list) : block IntMap.t =
  List.fold_left
    (fun map (b : block) -> IntMap.add b.id b map)
    IntMap.empty blocks

let get_succ cfg id = try IntMap.find id cfg.succ with Not_found -> []
let get_pred cfg id = try IntMap.find id cfg.pred with Not_found -> []

let compute_rpo (cfg : cfg) (entry : int) : int list =
  let visited = ref IntMap.empty in
  let order = ref [] in
  let rec dfs id =
    if not (IntMap.mem id !visited) then (
      visited := IntMap.add id true !visited;
      List.iter dfs (get_succ cfg id);
      order := id :: !order)
  in
  dfs entry;
  !order

let compute_rpo_back (cfg : cfg) (entry : int) : int list =
  compute_rpo cfg entry |> List.rev

let compute_bfs (cfg : cfg) (entry : int) : int list =
  let visited = ref IntMap.empty in
  let queue = Queue.create () in
  let order = ref [] in
  Queue.push entry queue;
  visited := IntMap.add entry true !visited;
  while not (Queue.is_empty queue) do
    let id = Queue.pop queue in
    order := id :: !order;
    List.iter
      (fun sid ->
        if not (IntMap.mem sid !visited) then (
          visited := IntMap.add sid true !visited;
          Queue.push sid queue))
      (get_succ cfg id)
  done;
  List.rev !order

let compute_dfs (cfg : cfg) (entry : int) : int list =
  let visited = ref IntMap.empty in
  let order = ref [] in
  let rec explore id =
    if not (IntMap.mem id !visited) then (
      visited := IntMap.add id true !visited;
      order := id :: !order;
      List.iter explore (get_succ cfg id))
  in
  explore entry;
  List.rev !order

let compute_linear (blocks : block list) : int list =
  List.map (fun (b : block) -> b.id) blocks

type cfg_order =
  | ReversePostorder
  | ReversePostorderBack
  | BreadthFirst
  | DepthFirst
  | Linear

let get_block_order (order : cfg_order) (cfg : cfg) (entry : int)
    (blocks : block list) : int list =
  match order with
  | ReversePostorder -> compute_rpo cfg entry
  | ReversePostorderBack -> compute_rpo_back cfg entry
  | BreadthFirst -> compute_bfs cfg entry
  | DepthFirst -> compute_dfs cfg entry
  | Linear -> compute_linear blocks
