open Helpers
module String_scc = Helpers.Cyclic_components.Make (String)

let make_graph edges =
  List.fold_left
    (fun g (src, dsts) ->
      let g = String_scc.add_node src g in
      List.fold_left
        (fun g dst -> String_scc.add_edge ~src ~target:dst g)
        g dsts)
    String_scc.empty edges

(* ── helpers ── *)

let pp_component c = "[" ^ String.concat ", " c ^ "]"
let pp_components cs = "[" ^ String.concat "; " (List.map pp_component cs) ^ "]"

let print_edges label edges =
  let edge_strs =
    List.map
      (fun (src, dsts) -> src ^ "->{" ^ String.concat "," dsts ^ "}")
      edges
  in
  Printf.printf "--- %s\n  graph: [%s]\n" label (String.concat "; " edge_strs)

(* ── kosaraju_scc ── *)

let test_scc_empty_graph () =
  Printf.printf "--- scc_empty_graph\n  graph: []\n";
  let sccs = String_scc.kosaraju_scc String_scc.empty in
  Printf.printf "  sccs: %s\n" (pp_components sccs)

let test_scc_single_node () =
  let edges = [ ("A", []) ] in
  print_edges "scc_single_node" edges;
  let g = make_graph edges in
  let sccs = String_scc.kosaraju_scc g in
  Printf.printf "  sccs: %s\n" (pp_components sccs)

let test_scc_self_loop () =
  let edges = [ ("A", [ "A" ]); ("B", []) ] in
  print_edges "scc_self_loop" edges;
  let g = make_graph edges in
  let sccs = String_scc.kosaraju_scc g in
  Printf.printf "  sccs: %s\n" (pp_components sccs)

let test_scc_no_cycle () =
  let edges = [ ("A", [ "B" ]); ("B", [ "C" ]); ("C", [ "D" ]); ("D", []) ] in
  print_edges "scc_no_cycle" edges;
  let g = make_graph edges in
  let sccs = String_scc.kosaraju_scc g in
  Printf.printf "  sccs: %s\n" (pp_components sccs)

let test_scc_simple_cycle () =
  let edges = [ ("A", [ "B" ]); ("B", [ "C" ]); ("C", [ "A" ]); ("D", []) ] in
  print_edges "scc_simple_cycle" edges;
  let g = make_graph edges in
  let sccs = String_scc.kosaraju_scc g in
  Printf.printf "  sccs: %s\n" (pp_components sccs)

let test_scc_two_cycles () =
  let edges =
    [ ("A", [ "B" ]); ("B", [ "A" ]); ("C", [ "D" ]); ("D", [ "C" ]) ]
  in
  print_edges "scc_two_cycles" edges;
  let g = make_graph edges in
  let sccs = String_scc.kosaraju_scc g in
  Printf.printf "  sccs: %s\n" (pp_components sccs)

let test_scc_complex () =
  let edges =
    [
      ("A", [ "B" ]);
      ("B", [ "C" ]);
      ("C", [ "A"; "D" ]);
      ("D", [ "E" ]);
      ("E", [ "D" ]);
    ]
  in
  print_edges "scc_complex" edges;
  let g = make_graph edges in
  let sccs = String_scc.kosaraju_scc g in
  Printf.printf "  sccs: %s\n" (pp_components sccs)

(* ── cyclic_components ── *)

let test_cyclic_empty_graph () =
  Printf.printf "--- cyclic_empty_graph\n  graph: []\n";
  let cycles = String_scc.cyclic_components String_scc.empty in
  Printf.printf "  cycles: %s\n" (pp_components cycles)

let test_cyclic_no_cycle () =
  let edges = [ ("A", [ "B" ]); ("B", [ "C" ]); ("C", [ "D" ]); ("D", []) ] in
  print_edges "cyclic_no_cycle" edges;
  let g = make_graph edges in
  let cycles = String_scc.cyclic_components g in
  Printf.printf "  cycles: %s\n" (pp_components cycles)

let test_cyclic_self_loop () =
  let edges = [ ("A", [ "A" ]); ("B", []) ] in
  print_edges "cyclic_self_loop" edges;
  let g = make_graph edges in
  let cycles = String_scc.cyclic_components g in
  Printf.printf "  cycles: %s\n" (pp_components cycles)

let test_cyclic_simple_cycle () =
  let edges = [ ("A", [ "B" ]); ("B", [ "C" ]); ("C", [ "A" ]); ("D", []) ] in
  print_edges "cyclic_simple_cycle" edges;
  let g = make_graph edges in
  let cycles = String_scc.cyclic_components g in
  Printf.printf "  cycles: %s\n" (pp_components cycles)

let test_cyclic_two_cycles () =
  let edges =
    [ ("A", [ "B" ]); ("B", [ "A" ]); ("C", [ "D" ]); ("D", [ "C" ]) ]
  in
  print_edges "cyclic_two_cycles" edges;
  let g = make_graph edges in
  let cycles = String_scc.cyclic_components g in
  Printf.printf "  cycles: %s\n" (pp_components cycles)

let test_cyclic_mixed () =
  let edges =
    [
      ("A", [ "B" ]); ("B", [ "C" ]); ("C", [ "A" ]); ("D", [ "E" ]); ("E", []);
    ]
  in
  print_edges "cyclic_mixed" edges;
  let g = make_graph edges in
  let cycles = String_scc.cyclic_components g in
  Printf.printf "  cycles: %s\n" (pp_components cycles)

let test_cyclic_complex () =
  let edges =
    [
      ("A", [ "B" ]);
      ("B", [ "C" ]);
      ("C", [ "A"; "D" ]);
      ("D", [ "E" ]);
      ("E", [ "D" ]);
    ]
  in
  print_edges "cyclic_complex" edges;
  let g = make_graph edges in
  let cycles = String_scc.cyclic_components g in
  Printf.printf "  cycles: %s\n" (pp_components cycles)

(* ── entry point ── *)

let () =
  test_scc_empty_graph ();
  Printf.printf "\n";
  test_scc_single_node ();
  Printf.printf "\n";
  test_scc_self_loop ();
  Printf.printf "\n";
  test_scc_no_cycle ();
  Printf.printf "\n";
  test_scc_simple_cycle ();
  Printf.printf "\n";
  test_scc_two_cycles ();
  Printf.printf "\n";
  test_scc_complex ();
  Printf.printf "\n";
  test_cyclic_empty_graph ();
  Printf.printf "\n";
  test_cyclic_no_cycle ();
  Printf.printf "\n";
  test_cyclic_self_loop ();
  Printf.printf "\n";
  test_cyclic_simple_cycle ();
  Printf.printf "\n";
  test_cyclic_two_cycles ();
  Printf.printf "\n";
  test_cyclic_mixed ();
  Printf.printf "\n";
  test_cyclic_complex ()
