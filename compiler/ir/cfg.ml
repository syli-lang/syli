open Cir

type cfg = {
  succ : (int, int list) Hashtbl.t;
  pred : (int, int list) Hashtbl.t;
}

let build_cfg (blocks : block list) : cfg =
  let succ = Hashtbl.create 16 in
  let pred = Hashtbl.create 16 in
  List.iter
    (fun (b : block) ->
      Hashtbl.replace succ b.id [];
      Hashtbl.replace pred b.id [])
    blocks;
  List.iter
    (fun (b : block) ->
      let successors =
        match b.terminator.node with
        | CR_Goto id -> [ id ]
        | CR_Switch { cases; default_block; _ } ->
            let case_targets = List.map (fun c -> c.target_block) cases in
            Option.to_list default_block @ case_targets
        | CR_CondBr { then_block; else_block; _ } -> [ then_block; else_block ]
        | CR_Return _ -> []
      in
      Hashtbl.replace succ b.id successors;
      List.iter
        (fun sid ->
          let preds = Hashtbl.find pred sid in
          Hashtbl.replace pred sid (b.id :: preds))
        successors)
    blocks;
  { succ; pred }

let build_block_map (blocks : block list) : (int, block) Hashtbl.t =
  let map = Hashtbl.create 16 in
  List.iter (fun (b : block) -> Hashtbl.add map b.id b) blocks;
  map

let get_succ cfg id = Hashtbl.find_opt cfg.succ id |> Option.value ~default:[]
let get_pred cfg id = Hashtbl.find_opt cfg.pred id |> Option.value ~default:[]

let compute_rpo (cfg : cfg) (entry : int) : int list =
  let visited = Hashtbl.create 16 in
  let order = ref [] in
  let rec dfs id =
    if not (Hashtbl.mem visited id) then (
      Hashtbl.add visited id true;
      List.iter dfs (get_succ cfg id);
      order := id :: !order)
  in
  dfs entry;
  !order

let compute_rpo_back (cfg : cfg) (entry : int) : int list =
  compute_rpo cfg entry |> List.rev

let compute_bfs (cfg : cfg) (entry : int) : int list =
  let visited = Hashtbl.create 16 in
  let queue = Queue.create () in
  let order = ref [] in
  Queue.push entry queue;
  Hashtbl.add visited entry true;
  while not (Queue.is_empty queue) do
    let id = Queue.pop queue in
    order := id :: !order;
    List.iter
      (fun sid ->
        if not (Hashtbl.mem visited sid) then (
          Hashtbl.add visited sid true;
          Queue.push sid queue))
      (get_succ cfg id)
  done;
  List.rev !order

let compute_dfs (cfg : cfg) (entry : int) : int list =
  let visited = Hashtbl.create 16 in
  let order = ref [] in
  let rec explore id =
    if not (Hashtbl.mem visited id) then (
      Hashtbl.add visited id true;
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
