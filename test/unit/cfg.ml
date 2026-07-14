module Cfg = Syli_ir.Cfg
open Syli_ir.Cir

let dummy_var = { id = 0; name = "__dummy"; ty = { id = 0; ir_type = CR_I64 } }
let void_ty = { id = 999; ir_type = CR_Void }
let make_terminator id node = { id; node }

let make_block id terminator =
  {
    id;
    label_id = id;
    statements = [];
    terminator;
    pred_blocks = [];
    succ_blocks = [];
  }

let string_of_int_list xs =
  "[" ^ String.concat ", " (List.map string_of_int xs) ^ "]"

let print_cfg_blocks label blocks =
  let entry =
    match blocks with h :: _ -> h | [] -> failwith "print_cfg_blocks: empty"
  in
  let dummy_fn : function_cir =
    {
      id = 0;
      name = "__test";
      params = [];
      locals = [];
      entry_block = entry;
      blocks;
      return_ty = void_ty;
      visibility = CR_Public;
    }
  in
  let prog : module_cir =
    {
      name = "Test";
      type_defs = [];
      functions = [ dummy_fn ];
      global_values = [];
      ffi_external_functions = [];
    }
  in
  Printf.printf "--- %s\n%s\n" label
    (Syli_ir.Cir_pretty_print.string_of_program prog)

let test_build_cfg_chain () =
  let b1 = make_block 1 (make_terminator 0 (CR_Goto 2)) in
  let b2 = make_block 2 (make_terminator 0 (CR_Return None)) in
  print_cfg_blocks "test_build_cfg_chain" [ b1; b2 ];
  let cfg = Cfg.build_cfg [ b1; b2 ] in
  Printf.printf "  succ[1] = %s\n" (string_of_int_list (Cfg.get_succ cfg 1));
  Printf.printf "  pred[2] = %s\n" (string_of_int_list (Cfg.get_pred cfg 2))

let test_build_cfg_switch () =
  let cases =
    [ { value = 0; target_block = 2 }; { value = 1; target_block = 3 } ]
  in
  let switch_term =
    CR_Switch { scrutinee = dummy_var; cases; default_block = Some 4 }
  in
  let b1 = make_block 1 (make_terminator 0 switch_term) in
  let b2 = make_block 2 (make_terminator 0 (CR_Return None)) in
  let b3 = make_block 3 (make_terminator 0 (CR_Return None)) in
  let b4 = make_block 4 (make_terminator 0 (CR_Return None)) in
  print_cfg_blocks "test_build_cfg_switch" [ b1; b2; b3; b4 ];
  let cfg = Cfg.build_cfg [ b1; b2; b3; b4 ] in
  Printf.printf "  succ[1] = %s\n" (string_of_int_list (Cfg.get_succ cfg 1));
  Printf.printf "  pred[2] = %s\n" (string_of_int_list (Cfg.get_pred cfg 2));
  Printf.printf "  pred[3] = %s\n" (string_of_int_list (Cfg.get_pred cfg 3));
  Printf.printf "  pred[4] = %s\n" (string_of_int_list (Cfg.get_pred cfg 4))

let test_compute_rpo_bfs_dfs_linear () =
  let b1 = make_block 1 (make_terminator 0 (CR_Goto 2)) in
  let b2 = make_block 2 (make_terminator 0 (CR_Goto 3)) in
  let b3 = make_block 3 (make_terminator 0 (CR_Return None)) in
  print_cfg_blocks "test_compute_rpo_bfs_dfs_linear" [ b1; b2; b3 ];
  let cfg = Cfg.build_cfg [ b1; b2; b3 ] in
  Printf.printf "  rpo      = %s\n" (string_of_int_list (Cfg.compute_rpo cfg 1));
  Printf.printf "  rpo_back = %s\n"
    (string_of_int_list (Cfg.compute_rpo_back cfg 1));
  Printf.printf "  bfs      = %s\n" (string_of_int_list (Cfg.compute_bfs cfg 1));
  Printf.printf "  dfs      = %s\n" (string_of_int_list (Cfg.compute_dfs cfg 1));
  Printf.printf "  linear   = %s\n"
    (string_of_int_list (Cfg.compute_linear [ b1; b2; b3 ]))

let test_get_block_order () =
  let b1 = make_block 1 (make_terminator 0 (CR_Goto 2)) in
  let b2 = make_block 2 (make_terminator 0 (CR_Goto 3)) in
  let b3 = make_block 3 (make_terminator 0 (CR_Return None)) in
  print_cfg_blocks "test_get_block_order" [ b1; b2; b3 ];
  let cfg = Cfg.build_cfg [ b1; b2; b3 ] in
  let blocks = [ b1; b2; b3 ] in
  Printf.printf "  rev_postorder      = %s\n"
    (string_of_int_list (Cfg.get_block_order Cfg.ReversePostorder cfg 1 blocks));
  Printf.printf "  rev_postorder_back = %s\n"
    (string_of_int_list
       (Cfg.get_block_order Cfg.ReversePostorderBack cfg 1 blocks));
  Printf.printf "  breadth_first      = %s\n"
    (string_of_int_list (Cfg.get_block_order Cfg.BreadthFirst cfg 1 blocks));
  Printf.printf "  depth_first        = %s\n"
    (string_of_int_list (Cfg.get_block_order Cfg.DepthFirst cfg 1 blocks));
  Printf.printf "  linear             = %s\n"
    (string_of_int_list (Cfg.get_block_order Cfg.Linear cfg 1 blocks))

let test_build_block_map () =
  let b1 = make_block 1 (make_terminator 0 (CR_Return None)) in
  let b2 = make_block 2 (make_terminator 0 (CR_Return None)) in
  print_cfg_blocks "test_build_block_map" [ b1; b2 ];
  let map = Cfg.build_block_map [ b1; b2 ] in
  let found_1 =
    match Hashtbl.find_opt map 1 with
    | Some b when b.id = 1 -> "1"
    | _ -> "not found"
  in
  let found_2 =
    match Hashtbl.find_opt map 2 with
    | Some b when b.id = 2 -> "2"
    | _ -> "not found"
  in
  Printf.printf "  block_map[1] = %s\n" found_1;
  Printf.printf "  block_map[2] = %s\n" found_2

let test_bfs_vs_dfs_diamond () =
  let b1 =
    make_block 1
      (make_terminator 0
         (CR_CondBr { cond = dummy_var; then_block = 2; else_block = 3 }))
  in
  let b2 = make_block 2 (make_terminator 0 (CR_Goto 4)) in
  let b3 = make_block 3 (make_terminator 0 (CR_Goto 4)) in
  let b4 = make_block 4 (make_terminator 0 (CR_Return None)) in
  let blocks = [ b1; b2; b3; b4 ] in
  print_cfg_blocks "test_bfs_vs_dfs_diamond" blocks;
  let cfg = Cfg.build_cfg blocks in
  Printf.printf "  bfs = %s\n" (string_of_int_list (Cfg.compute_bfs cfg 1));
  Printf.printf "  dfs = %s\n" (string_of_int_list (Cfg.compute_dfs cfg 1))

let () =
  test_build_cfg_chain ();
  Printf.printf "\n";
  test_build_cfg_switch ();
  Printf.printf "\n";
  test_compute_rpo_bfs_dfs_linear ();
  Printf.printf "\n";
  test_get_block_order ();
  Printf.printf "\n";
  test_bfs_vs_dfs_diamond ();
  Printf.printf "\n";
  test_build_block_map ()
