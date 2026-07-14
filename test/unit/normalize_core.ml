open Syli_core.Core_ast
module NC = Syli_core.Normalize

let dummy_loc = { filename = "test"; span = { start_pos = 0; end_pos = 0 } }
let unit_ty = { ty_desc = CTy_Constant CTy_Unit }
let ident ?(id = 0) name = { fullname = name; id; loc = dummy_loc }
let mk_expr id node = { id; node; loc = dummy_loc; ty = unit_ty }
let mk_const_unit id = mk_expr id (CExp_Constant CConst_Unit)

let mk_lambda_expr id params body =
  mk_expr id (CExp_Lambda { params; body; ret_ty = unit_ty })

let mk_toplevel_let id name value =
  {
    id;
    structure_item_desc =
      CStr_Let { rec_flag = CNonRecursive; name = ident name; value };
  }

let mk_prog structure_items =
  {
    id = 0;
    name = ident "Test";
    structure_items;
    signature_items = [];
    has_main_function = false;
  }

let print_prog label prog =
  Printf.printf "--- %s\n%s\n" label (Syli_core.Pp.string_of_program prog)

let test_toplevel_last_occurrence_keeps_original_name () =
  let lam1 = mk_lambda_expr 10 [] (mk_const_unit 11) in
  let lam2 = mk_lambda_expr 12 [] (mk_const_unit 13) in
  let prog =
    mk_prog [ mk_toplevel_let 1 "f" lam1; mk_toplevel_let 2 "f" lam2 ]
  in
  print_prog "test_toplevel_last_occurrence_keeps_original_name: input" prog;
  let renamed = NC.run prog in
  print_prog "test_toplevel_last_occurrence_keeps_original_name: output" renamed

let test_local_shadowing_renames_and_updates_uses () =
  let x_param = ident ~id:1 "x" in
  let let_value_uses_param = mk_expr 20 (CExp_Ident x_param) in
  let local_let =
    mk_expr 21
      (CExp_Let
         {
           rec_flag = CNonRecursive;
           name = ident ~id:2 "x";
           value = let_value_uses_param;
         })
  in
  let trailing_use = mk_expr 22 (CExp_Ident (ident ~id:3 "x")) in
  let body = mk_expr 23 (CExp_Seq [ local_let; trailing_use ]) in
  let lam = mk_lambda_expr 24 [ x_param ] body in
  let prog = mk_prog [ mk_toplevel_let 3 "g" lam ] in
  print_prog "test_local_shadowing_renames_and_updates_uses: input" prog;
  let renamed = NC.run prog in
  print_prog "test_local_shadowing_renames_and_updates_uses: output" renamed

let test_second_local_shadow_renamed () =
  let let1 =
    mk_expr 30
      (CExp_Let
         {
           rec_flag = CNonRecursive;
           name = ident ~id:10 "x";
           value = mk_const_unit 31;
         })
  in
  let let2 =
    mk_expr 32
      (CExp_Let
         {
           rec_flag = CNonRecursive;
           name = ident ~id:11 "x";
           value = mk_const_unit 33;
         })
  in
  let use_x = mk_expr 34 (CExp_Ident (ident ~id:12 "x")) in
  let body = mk_expr 35 (CExp_Seq [ let1; let2; use_x ]) in
  let lam = mk_lambda_expr 36 [] body in
  let prog = mk_prog [ mk_toplevel_let 4 "h" lam ] in
  print_prog "test_second_local_shadow_renamed: input" prog;
  let renamed = NC.run prog in
  print_prog "test_second_local_shadow_renamed: output" renamed

let () =
  test_toplevel_last_occurrence_keeps_original_name ();
  Printf.printf "\n";
  test_local_shadowing_renames_and_updates_uses ();
  Printf.printf "\n";
  test_second_local_shadow_renamed ()
