open Syli_core.Core_ast
open Syli_core.Closure_analysis

let dummy_loc = { filename = "test"; span = { start_pos = 0; end_pos = 0 } }
let unit_ty = { ty_desc = CTy_Constant CTy_Unit }
let i64_ty = { ty_desc = CTy_Constant CTy_Int64 }
let ident ?(id = 0) name = { fullname = name; id; loc = dummy_loc }
let mk_expr ?(ty = unit_ty) id node = { id; node; loc = dummy_loc; ty }
let mk_const_unit id = mk_expr id (CExp_Constant CConst_Unit)
let mk_const_i64 id n = mk_expr ~ty:i64_ty id (CExp_Constant (CConst_IntLit n))

let mk_prog ?(signature_items = []) structure_items =
  {
    id = 0;
    name = ident "Test";
    structure_items;
    signature_items;
    has_main_function = false;
  }

let mk_lambda_expr ?(ret_ty = unit_ty) id params body =
  mk_expr id (CExp_Lambda { params; body; ret_ty })

let mk_toplevel_let id name value =
  {
    id;
    structure_item_desc =
      CStr_Let { rec_flag = CNonRecursive; name = ident name; value };
  }

let print_result result =
  let entries =
    Hashtbl.fold (fun k v acc -> (k, v) :: acc) result.closure_infos []
    |> List.sort (fun (a, _) (b, _) -> Int.compare a b)
  in
  List.iter
    (fun (id, info) ->
      let var_strs =
        List.map
          (fun v -> Printf.sprintf "%s#%d" v.fullname v.id)
          (VarIdSet.elements info.free_vars)
      in
      Printf.printf "  lambda#%d: free_vars={%s}\n" id
        (String.concat ", " var_strs))
    entries

let print_prog label prog =
  Printf.printf "--- %s\n%s\n" label (Syli_core.Pp.string_of_program prog)

let test_nested_lambda_captures_outer_param () =
  let outer_param = ident ~id:1 "x" in
  let inner_param = ident ~id:2 "y" in
  let inner_body = mk_expr 32 (CExp_Ident outer_param) in
  let inner_lam = mk_lambda_expr 31 [ inner_param ] inner_body in
  let outer_lam = mk_lambda_expr 30 [ outer_param ] inner_lam in
  let prog = mk_prog [ mk_toplevel_let 4 "f" outer_lam ] in
  print_prog "test_nested_lambda_captures_outer_param" prog;
  let result = run prog in
  print_result result

let test_seq_let_binds_for_following_expr () =
  let x = ident ~id:3 "x" in
  let let_x =
    mk_expr 40
      (CExp_Let { rec_flag = CNonRecursive; name = x; value = mk_const_unit 41 })
  in
  let body = mk_expr 42 (CExp_Seq [ let_x; mk_expr 43 (CExp_Ident x) ]) in
  let lam = mk_lambda_expr 44 [] body in
  let prog = mk_prog [ mk_toplevel_let 5 "g" lam ] in
  print_prog "test_seq_let_binds_for_following_expr" prog;
  let result = run prog in
  print_result result

let () =
  test_nested_lambda_captures_outer_param ();
  Printf.printf "\n";
  test_seq_let_binds_for_following_expr ()
