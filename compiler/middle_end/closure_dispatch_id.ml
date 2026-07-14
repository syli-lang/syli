open Syli_common
open Helpers

type dispatch_id = int
type graph = { root_ids : int list; edges : int list IntMap.t }

module Edge = struct
  type t = int * int

  let compare (s1, t1) (s2, t2) =
    match Int.compare s1 s2 with 0 -> Int.compare t1 t2 | c -> c
end

module EdgeMap = Map.Make (Edge)

type offsets = int EdgeMap.t
type t = offsets

let compute_n (g : graph) =
  let rec n memo v =
    match IntMap.find_opt v memo with
    | Some count -> (count, memo)
    | None ->
        let children =
          match IntMap.find_opt v g.edges with None -> [] | Some xs -> xs
        in
        let count, memo =
          match children with
          | [] -> (1, memo)
          | _ ->
              List.fold_left
                (fun (acc, memo) child ->
                  let child_count, memo = n memo child in
                  (acc + child_count, memo))
                (0, memo) children
        in
        let memo = IntMap.add v count memo in
        (count, memo)
  in
  let _, memo =
    List.fold_left
      (fun (_, memo) root -> n memo root)
      (0, IntMap.empty) g.root_ids
  in
  memo

let compute_offsets graph npaths =
  IntMap.fold
    (fun src children offsets ->
      let _, offsets =
        List.fold_left
          (fun (prefix, offsets) child ->
            let offsets = EdgeMap.add (src, child) prefix offsets in
            let prefix =
              prefix
              +
              match IntMap.find_opt child npaths with
              | Some x -> x
              | None -> 0
            in
            (prefix, offsets))
          (0, offsets) children
      in
      offsets)
    graph.edges EdgeMap.empty

let compute_dispatch_ids graph =
  let npaths = compute_n graph in
  compute_offsets graph npaths

let edge_weight t ~src ~target =
  EdgeMap.find_opt (src, target) t |> Option.value ~default:0
