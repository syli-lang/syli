(** Unit tests for liveness analysis on OIR. *)

module L = Middle_end.Liveness
open L
open Syli_ir.Oir
open Syli_common

(* ── Helpers ──────────────────────────────────────────────────── *)

let fresh () = fresh_id ()
let i64_ty : ty = { id = fresh (); ir_type = OR_I64 }

let obj_ty : ty =
  { id = fresh (); ir_type = OR_Obj { named = Some "Obj"; args = [] } }

let make_var name ty = { id = fresh (); name; ty }
let obj_var name = make_var name obj_ty
let i64_var name = make_var name i64_ty
let make_stmt id node ty = { id; node; ty }
let make_term id node = { id; node }

let make_block id label_id stmts term =
  {
    id;
    label_id;
    statements = stmts;
    terminator = term;
    pred_blocks = [];
    succ_blocks = [];
  }

let make_fn name ~locals entry blocks =
  {
    id = fresh ();
    name;
    params = [];
    locals;
    entry_block = entry;
    blocks;
    return_ty = i64_ty;
    visibility = OR_Public;
  }

let print_fn label (fn : function_oir) =
  let prog : module_oir =
    {
      name = "Test";
      type_defs = [];
      functions = [ fn ];
      global_values = [];
      ffi_external_functions = [];
    }
  in
  Printf.printf "--- %s\n%s\n" label
    (Syli_ir.Oir_pretty_print.string_of_program prog)

let var_name_by_id (fn : function_oir) id =
  let all_vars : var list = fn.params @ fn.locals in
  let rec find (vs : var list) =
    match vs with
    | [] -> Printf.sprintf "?%d" id
    | v :: rest -> if v.id = id then v.name else find rest
  in
  find all_vars

let print_live_set label fn sid (info : L.live_info) =
  let before_str =
    String.concat ", "
      (List.map (var_name_by_id fn) (IntSet.elements info.live_before))
  in
  let after_str =
    String.concat ", "
      (List.map (var_name_by_id fn) (IntSet.elements info.live_after))
  in
  Printf.printf "  stmt %d: live_before={%s}  live_after={%s}\n" sid before_str
    after_str

let print_live_map label fn live_map =
  Printf.printf "--- %s\n" label;
  IntMap.iter (fun sid info -> print_live_set label fn sid info) live_map

(* ── Test: single block, two ref vars ─────────────────────────── *)

let test_single_block () =
  let x = obj_var "x" in
  let y = obj_var "y" in
  let s1 =
    make_stmt 1
      (OR_Object_create
         {
           dst = x;
           size = OR_OConstant (OR_IntLit "8", i64_ty);
           layout =
             OR_Record
               { field_count = 1; field_types = [ i64_ty ]; tag_variant = 0 };
           initializer_fn = None;
         })
      obj_ty
  in
  let s2 =
    make_stmt 2
      (OR_Object_create
         {
           dst = y;
           size = OR_OConstant (OR_IntLit "8", i64_ty);
           layout =
             OR_Record
               { field_count = 1; field_types = [ i64_ty ]; tag_variant = 0 };
           initializer_fn = None;
         })
      obj_ty
  in
  let s3 =
    make_stmt 3 (OR_RC_op { op = OR_RC_check_release; obj = x }) obj_ty
  in
  let s4 =
    make_stmt 4 (OR_RC_op { op = OR_RC_check_release; obj = y }) obj_ty
  in
  let term = make_term 99 (OR_Return None) in
  let bb = make_block 10 10 [ s1; s2; s3; s4 ] term in
  let fn = make_fn "test_single" ~locals:[ x; y ] bb [ bb ] in
  print_fn "test_single_block: input" fn;
  let live_map = L.analyze fn in
  print_live_map "test_single_block: live_map" fn live_map

(* ── Test: two blocks with branch ─────────────────────────────── *)

let test_two_blocks () =
  let cond = i64_var "cond" in
  let x = obj_var "x" in
  (* bb1 (entry): create x, branch on cond *)
  let s1 =
    make_stmt 1
      (OR_Object_create
         {
           dst = x;
           size = OR_OConstant (OR_IntLit "8", i64_ty);
           layout =
             OR_Record
               { field_count = 1; field_types = [ i64_ty ]; tag_variant = 0 };
           initializer_fn = None;
         })
      obj_ty
  in
  let term1 =
    make_term 10 (OR_CondBr { cond; then_block = 100; else_block = 101 })
  in
  let bb1 = make_block 20 20 [ s1 ] term1 in
  (* bb2 (then): use x, return *)
  let s2 =
    make_stmt 2 (OR_RC_op { op = OR_RC_check_release; obj = x }) obj_ty
  in
  let term2 = make_term 11 (OR_Return None) in
  let bb2 = make_block 100 100 [ s2 ] term2 in
  (* bb3 (else): return (x not used here) *)
  let term3 = make_term 12 (OR_Return None) in
  let bb3 = make_block 101 101 [] term3 in
  (* entry block must be bb1 *)
  let fn =
    make_fn "test_two_blocks" ~locals:[ cond; x ] bb1 [ bb1; bb2; bb3 ]
  in
  print_fn "test_two_blocks: input" fn;
  let live_map = L.analyze fn in
  print_live_map "test_two_blocks: live_map" fn live_map

(* ── Test: Store_global and Call affect liveness ──────────────── *)

let test_store_global_and_call () =
  let x = obj_var "x" in
  let y = obj_var "y" in
  (* create x, store x to global, create y, call fn(y) *)
  let s1 =
    make_stmt 1
      (OR_Object_create
         {
           dst = x;
           size = OR_OConstant (OR_IntLit "8", i64_ty);
           layout =
             OR_Record
               { field_count = 1; field_types = [ i64_ty ]; tag_variant = 0 };
           initializer_fn = None;
         })
      obj_ty
  in
  let s2 =
    make_stmt 2 (OR_Store_global { global = "g_x"; value = OR_OVar x }) i64_ty
  in
  let s3 =
    make_stmt 3
      (OR_Object_create
         {
           dst = y;
           size = OR_OConstant (OR_IntLit "8", i64_ty);
           layout =
             OR_Record
               { field_count = 1; field_types = [ i64_ty ]; tag_variant = 0 };
           initializer_fn = None;
         })
      obj_ty
  in
  let s4 =
    make_stmt 4
      (OR_Call { dst = y; target = Direct "fn"; args = [ OR_OVar y ] })
      obj_ty
  in
  let s5 =
    make_stmt 5 (OR_RC_op { op = OR_RC_check_release; obj = x }) obj_ty
  in
  let term = make_term 99 (OR_Return None) in
  let bb = make_block 10 10 [ s1; s2; s3; s4; s5 ] term in
  let fn = make_fn "test_store_global_and_call" ~locals:[ x; y ] bb [ bb ] in
  print_fn "test_store_global_and_call: input" fn;
  let live_map = L.analyze fn in
  print_live_map "test_store_global_and_call: live_map" fn live_map

(* ── Main ─────────────────────────────────────────────────────── *)

let () =
  test_single_block ();
  Printf.printf "\n";
  test_two_blocks ();
  Printf.printf "\n";
  test_store_global_and_call ()
