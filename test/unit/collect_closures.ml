open Syli_core.Core_ast
open Syli_core.Closure_analysis

let dummy_loc = { filename = "test"; span = { start_pos = 0; end_pos = 0 } }
let unit_ty = CTy_Constant CTy_Unit

let mk_expr ?(ty_desc = unit_ty) id node : expr =
  let ty = { ty_desc } in
  { id; node; loc = dummy_loc; ty }

let mk_structure_item id structure_item_desc : structure_item =
  { id; structure_item_desc }

let mk_toplevel_let id rec_flag name value : structure_item =
  mk_structure_item id
    (CStr_Let
       { rec_flag; name = { fullname = name; id = 0; loc = dummy_loc }; value })

let ident ?(id = 0) name = { fullname = name; id; loc = dummy_loc }

let mk_ident_expr eid name vid =
  mk_expr eid (CExp_Ident { fullname = name; id = vid; loc = dummy_loc })

let mk_const_unit id = mk_expr id (CExp_Constant CConst_Unit)

let mk_lambda ?(ty_desc = unit_ty) params body : lambda =
  { params; body; ret_ty = { ty_desc } }

let mk_prog structure_items =
  {
    id = 0;
    name = { fullname = "Test"; id = 0; loc = dummy_loc };
    structure_items;
    signature_items = [];
    has_main_function = false;
  }

let pp_var_ids ids =
  "{"
  ^ String.concat ", "
      (List.map
         (fun id -> Printf.sprintf "%s#%d" id.fullname id.id)
         (VarIdSet.elements ids))
  ^ "}"

let pp_lambda (lam : lambda) =
  let params =
    List.map
      (fun (p : ident) -> Printf.sprintf "%s#%d" p.fullname p.id)
      lam.params
  in
  Printf.sprintf "lambda(params=[%s])" (String.concat ", " params)

let pp_closure_info (info : closure_info) =
  Printf.sprintf "  { id=%d  free_vars=%s  %s }" info.id
    (pp_var_ids info.free_vars)
    (pp_lambda info.lambda)

let pp_result (result : core_closure_analysis) =
  let entries =
    Hashtbl.fold (fun k v acc -> (k, v) :: acc) result.closure_infos []
    |> List.sort (fun (a, _) (b, _) -> Int.compare a b)
  in
  let body =
    if entries = [] then "  (no lambdas registered)"
    else String.concat "\n" (List.map (fun (_, v) -> pp_closure_info v) entries)
  in
  Printf.sprintf "core_closure_analysis {\n  closure_infos =\n%s\n}" body

let print_prog label prog =
  Printf.printf "--- %s\n%s\n" label (Syli_core.Pp.string_of_program prog)

let print_result label result =
  Printf.printf "--- %s\n%s\n" label (pp_result result)

(* empty program *)
let test_empty_program_has_no_lambdas () =
  let prog = mk_prog [] in
  print_prog "test_empty_program_has_no_lambdas" prog;
  let result = run prog in
  print_result "test_empty_program_has_no_lambdas: result" result

(* let f = lambda () -> () *)
let test_toplevel_lambda_registers_decl_id () =
  let body = mk_const_unit 10 in
  let lambda = mk_lambda [] body in
  let value = mk_expr 2 (CExp_Lambda lambda) in
  let decl = mk_toplevel_let 1 CNonRecursive "f" value in
  let prog = mk_prog [ decl ] in
  print_prog "test_toplevel_lambda_registers_decl_id" prog;
  let result = run prog in
  print_result "test_toplevel_lambda_registers_decl_id: result" result

(* let f = lambda () -> () *)
let test_toplevel_lambda_registers_expr_id () =
  let body = mk_const_unit 10 in
  let lambda = mk_lambda [] body in
  let value = mk_expr 2 (CExp_Lambda lambda) in
  let decl = mk_toplevel_let 1 CNonRecursive "f" value in
  let prog = mk_prog [ decl ] in
  print_prog "test_toplevel_lambda_registers_expr_id" prog;
  let result = run prog in
  print_result "test_toplevel_lambda_registers_expr_id: result" result

(* let f = lambda () -> () *)
let test_toplevel_unit_body_has_no_free_vars_on_expr_entry () =
  let body = mk_const_unit 10 in
  let lambda = mk_lambda [] body in
  let value = mk_expr 2 (CExp_Lambda lambda) in
  let decl = mk_toplevel_let 1 CNonRecursive "f" value in
  let prog = mk_prog [ decl ] in
  print_prog "test_toplevel_unit_body_has_no_free_vars_on_expr_entry" prog;
  let result = run prog in
  print_result "test_toplevel_unit_body_has_no_free_vars_on_expr_entry: result"
    result

(* let f = lambda x -> x + y *)
let test_param_is_not_free_on_expr_entry () =
  let x_id = 99 in
  let body = mk_ident_expr 30 "x" x_id in
  let lambda = mk_lambda [ ident ~id:x_id "x" ] body in
  let value = mk_expr 31 (CExp_Lambda lambda) in
  let decl = mk_toplevel_let 32 CNonRecursive "f" value in
  let prog = mk_prog [ decl ] in
  print_prog "test_param_is_not_free_on_expr_entry" prog;
  let result = run prog in
  print_result "test_param_is_not_free_on_expr_entry: result" result

(* let f = lambda () -> y *)
let test_free_var_is_captured_on_expr_entry () =
  let y_id = 55 in
  let body = mk_ident_expr 40 "y" y_id in
  let lambda = mk_lambda [] body in
  let value = mk_expr 41 (CExp_Lambda lambda) in
  let decl = mk_toplevel_let 42 CNonRecursive "f" value in
  let prog = mk_prog [ decl ] in
  print_prog "test_free_var_is_captured_on_expr_entry" prog;
  let result = run prog in
  print_result "test_free_var_is_captured_on_expr_entry: result" result

(* let f1 = lambda () -> (); let f2 = lambda () -> y *)
let test_first_lambda_has_no_free_vars () =
  let body1 = mk_const_unit 50 in
  let lam1 = mk_lambda [] body1 in
  let val1 = mk_expr 51 (CExp_Lambda lam1) in
  let decl1 = mk_toplevel_let 52 CNonRecursive "f1" val1 in
  let y_id = 60 in
  let body2 = mk_ident_expr 53 "y" y_id in
  let lam2 = mk_lambda [] body2 in
  let val2 = mk_expr 54 (CExp_Lambda lam2) in
  let decl2 = mk_toplevel_let 55 CNonRecursive "f2" val2 in
  let prog = mk_prog [ decl1; decl2 ] in
  print_prog "test_first_lambda_has_no_free_vars" prog;
  let result = run prog in
  print_result "test_first_lambda_has_no_free_vars: result" result

(* let f1 = lambda () -> (); let f2 = lambda () -> y *)
let test_second_lambda_captures_outer_var () =
  let body1 = mk_const_unit 50 in
  let lam1 = mk_lambda [] body1 in
  let val1 = mk_expr 51 (CExp_Lambda lam1) in
  let decl1 = mk_toplevel_let 52 CNonRecursive "f1" val1 in
  let y_id = 60 in
  let body2 = mk_ident_expr 53 "y" y_id in
  let lam2 = mk_lambda [] body2 in
  let val2 = mk_expr 54 (CExp_Lambda lam2) in
  let decl2 = mk_toplevel_let 55 CNonRecursive "f2" val2 in
  let prog = mk_prog [ decl1; decl2 ] in
  print_prog "test_second_lambda_captures_outer_var" prog;
  let result = run prog in
  print_result "test_second_lambda_captures_outer_var: result" result

(* let f = lambda a b -> a; z *)
let test_first_param_is_not_free () =
  let a_id = 70 in
  let b_id = 71 in
  let z_id = 72 in
  let body =
    mk_expr 60
      (CExp_Seq [ mk_ident_expr 61 "a" a_id; mk_ident_expr 62 "z" z_id ])
  in
  let lambda = mk_lambda [ ident ~id:a_id "a"; ident ~id:b_id "b" ] body in
  let value = mk_expr 63 (CExp_Lambda lambda) in
  let decl = mk_toplevel_let 64 CNonRecursive "f" value in
  let prog = mk_prog [ decl ] in
  print_prog "test_first_param_is_not_free" prog;
  let result = run prog in
  print_result "test_first_param_is_not_free: result" result

(* let f = lambda a b -> a; z *)
let test_second_param_is_not_free () =
  let a_id = 70 in
  let b_id = 71 in
  let z_id = 72 in
  let body =
    mk_expr 60
      (CExp_Seq [ mk_ident_expr 61 "a" a_id; mk_ident_expr 62 "z" z_id ])
  in
  let lambda = mk_lambda [ ident ~id:a_id "a"; ident ~id:b_id "b" ] body in
  let value = mk_expr 63 (CExp_Lambda lambda) in
  let decl = mk_toplevel_let 64 CNonRecursive "f" value in
  let prog = mk_prog [ decl ] in
  print_prog "test_second_param_is_not_free" prog;
  let result = run prog in
  print_result "test_second_param_is_not_free: result" result

(* let f = lambda a b -> a; z *)
let test_non_param_is_free () =
  let a_id = 70 in
  let b_id = 71 in
  let z_id = 72 in
  let body =
    mk_expr 60
      (CExp_Seq [ mk_ident_expr 61 "a" a_id; mk_ident_expr 62 "z" z_id ])
  in
  let lambda = mk_lambda [ ident ~id:a_id "a"; ident ~id:b_id "b" ] body in
  let value = mk_expr 63 (CExp_Lambda lambda) in
  let decl = mk_toplevel_let 64 CNonRecursive "f" value in
  let prog = mk_prog [ decl ] in
  print_prog "test_non_param_is_free" prog;
  let result = run prog in
  print_result "test_non_param_is_free: result" result

let () =
  test_empty_program_has_no_lambdas ();
  Printf.printf "\n";
  test_toplevel_lambda_registers_decl_id ();
  Printf.printf "\n";
  test_toplevel_lambda_registers_expr_id ();
  Printf.printf "\n";
  test_toplevel_unit_body_has_no_free_vars_on_expr_entry ();
  Printf.printf "\n";
  test_param_is_not_free_on_expr_entry ();
  Printf.printf "\n";
  test_free_var_is_captured_on_expr_entry ();
  Printf.printf "\n";
  test_first_lambda_has_no_free_vars ();
  Printf.printf "\n";
  test_second_lambda_captures_outer_var ();
  Printf.printf "\n";
  test_first_param_is_not_free ();
  Printf.printf "\n";
  test_second_param_is_not_free ();
  Printf.printf "\n";
  test_non_param_is_free ()
