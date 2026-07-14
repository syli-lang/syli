open Syli_ir.Cir
open Syli_common
module CG = Middle_end.Closure_graph

let i64_ty = { id = 1; ir_type = CR_I64 }
let double_ty = { id = 4; ir_type = CR_Double }
let void_ty = { id = 3; ir_type = CR_Void }

let arrow_ty (param_tys : ty list) (ret_ty : ty) : ty =
  { id = fresh_id (); ir_type = CR_Arrow (param_tys, ret_ty) }

let make_var (id : int) (name : string) (ty : ty) : var = { id; name; ty }

let make_stmt (id : int) (node : statement_node) : statement =
  { id; node; ty = void_ty }

let make_block (stmts : statement list) : block =
  {
    id = fresh_id ();
    label_id = fresh_id ();
    statements = stmts;
    terminator = { id = fresh_id (); node = CR_Return None };
    pred_blocks = [];
    succ_blocks = [];
  }

let make_fn (name : string) (blocks : block list) : function_cir =
  {
    id = fresh_id ();
    name;
    params = [];
    locals = [];
    entry_block = List.hd blocks;
    blocks;
    return_ty = void_ty;
    visibility = CR_Public;
  }

let make_prog (fns : function_cir list) : module_cir =
  {
    name = "Test";
    type_defs = [];
    functions = fns;
    global_values = [];
    ffi_external_functions = [];
  }

let print_prog label prog =
  Printf.printf "--- %s\n%s\n" label
    (Syli_ir.Cir_pretty_print.string_of_program prog)

let pp_node_summary ((node_id, summary) : int * CG.summary) =
  let root_str =
    match summary.root with
    | CG.OR_Make_closure (fn_name, _) ->
        Printf.sprintf "Make_closure(%s)" fn_name
    | CG.OR_From_Arg_Fn src_id -> Printf.sprintf "From_Arg_Fn(%d)" src_id
  in
  let pp_ty t = Syli_ir.Cir_pretty_print.string_of_ty t in
  Printf.sprintf
    "    node %d: root=%s  fv_count=%d  rem_arg_tys=[%s]  ret_ty=%s" node_id
    root_str summary.free_var_count
    (String.concat ", " (List.map pp_ty summary.remaining_arg_tys))
    (pp_ty summary.ret_ty)

let pp_closures (t : CG.t) =
  let summaries = IntMap.bindings t.graph.node_summaries in
  let flat =
    List.concat_map
      (fun (nid, slist) -> List.map (fun s -> (nid, s)) slist)
      summaries
  in
  let node_strs = List.map pp_node_summary flat in
  Printf.printf "  node_summaries:\n%s\n"
    (if node_strs = [] then "    (none)" else String.concat "\n" node_strs);
  Printf.printf "  generic_nodes: {%s}\n"
    (String.concat ", "
       (List.map string_of_int (IntSet.elements t.generic_nodes)))

let test_make_closure_node () =
  let dst = make_var 10 "f" (arrow_ty [ i64_ty; i64_ty ] i64_ty) in
  let stmt =
    make_stmt 100
      (CR_Make_closure
         {
           dst;
           fn = "Test.add";
           free_vars = [];
           captured_args = [];
           initializer_fn = None;
         })
  in
  let prog = make_prog [ make_fn "test" [ make_block [ stmt ] ] ] in
  print_prog "test_make_closure_node" prog;
  let t = CG.analyze prog in
  Printf.printf "--- test_make_closure_node: result\n";
  pp_closures t

let test_make_closure_with_captured () =
  let dst = make_var 10 "f" (arrow_ty [ i64_ty ] i64_ty) in
  let stmt =
    make_stmt 100
      (CR_Make_closure
         {
           dst;
           fn = "Test.add";
           free_vars = [];
           captured_args = [ CR_OConstant (CR_IntLit "1", i64_ty) ];
           initializer_fn = None;
         })
  in
  let prog = make_prog [ make_fn "test" [ make_block [ stmt ] ] ] in
  print_prog "test_make_closure_with_captured" prog;
  let t = CG.analyze prog in
  Printf.printf "--- test_make_closure_with_captured: result\n";
  pp_closures t

let test_chain_make_closure_apply () =
  let clos_ty = arrow_ty [ i64_ty ] i64_ty in
  let clos = make_var 10 "c" clos_ty in
  let make =
    make_stmt 100
      (CR_Make_closure
         {
           dst = clos;
           fn = "Test.add";
           free_vars = [];
           captured_args = [ CR_OConstant (CR_IntLit "1", i64_ty) ];
           initializer_fn = None;
         })
  in
  let result = make_var 20 "r" i64_ty in
  let apply =
    make_stmt 200
      (CR_Call
         {
           dst = result;
           target = Apply { closure = clos };
           args = [ CR_OConstant (CR_IntLit "2", i64_ty) ];
         })
  in
  let prog = make_prog [ make_fn "test" [ make_block [ make; apply ] ] ] in
  print_prog "test_chain_make_closure_apply" prog;
  let t = CG.analyze prog in
  Printf.printf "--- test_chain_make_closure_apply: result\n";
  pp_closures t

let test_partial_apply_closure () =
  let clos_ty = arrow_ty [ i64_ty; i64_ty ] i64_ty in
  let clos = make_var 10 "c" clos_ty in
  let make =
    make_stmt 100
      (CR_Make_closure
         {
           dst = clos;
           fn = "Test.add";
           free_vars = [];
           captured_args = [ CR_OConstant (CR_IntLit "1", i64_ty) ];
           initializer_fn = None;
         })
  in
  let partial = make_var 15 "p" (arrow_ty [ i64_ty; i64_ty ] i64_ty) in
  let pstmt =
    make_stmt 150
      (CR_Partial_apply
         {
           dst = partial;
           closure = clos;
           new_args = [ CR_OConstant (CR_IntLit "2", i64_ty) ];
         })
  in
  let result = make_var 20 "r" i64_ty in
  let apply =
    make_stmt 200
      (CR_Call
         {
           dst = result;
           target = Apply { closure = partial };
           args = [ CR_OConstant (CR_IntLit "3", i64_ty) ];
         })
  in
  let prog =
    make_prog [ make_fn "test" [ make_block [ make; pstmt; apply ] ] ]
  in
  print_prog "test_partial_apply_closure" prog;
  let t = CG.analyze prog in
  Printf.printf "--- test_partial_apply_closure: result\n";
  pp_closures t

let test_dispatch_edge_weight () =
  let clos_ty = arrow_ty [ i64_ty; i64_ty ] i64_ty in
  let clos = make_var 10 "c" clos_ty in
  let make =
    make_stmt 100
      (CR_Make_closure
         {
           dst = clos;
           fn = "Test.add";
           free_vars = [];
           captured_args = [ CR_OConstant (CR_IntLit "1", i64_ty) ];
           initializer_fn = None;
         })
  in
  let partial = make_var 15 "p" (arrow_ty [ i64_ty; i64_ty ] i64_ty) in
  let pstmt =
    make_stmt 150
      (CR_Partial_apply
         {
           dst = partial;
           closure = clos;
           new_args = [ CR_OConstant (CR_IntLit "2", i64_ty) ];
         })
  in
  let result = make_var 20 "r" i64_ty in
  let apply =
    make_stmt 200
      (CR_Call
         {
           dst = result;
           target = Apply { closure = partial };
           args = [ CR_OConstant (CR_IntLit "3", i64_ty) ];
         })
  in
  let prog =
    make_prog [ make_fn "test" [ make_block [ make; pstmt; apply ] ] ]
  in
  print_prog "test_dispatch_edge_weight" prog;
  let t = CG.analyze prog in
  Printf.printf "--- test_dispatch_edge_weight: result\n";
  pp_closures t

let test_node_dispatch_possibilities () =
  let clos_ty = arrow_ty [ i64_ty; i64_ty ] i64_ty in
  let clos = make_var 10 "c" clos_ty in
  let make =
    make_stmt 100
      (CR_Make_closure
         {
           dst = clos;
           fn = "Test.add";
           free_vars = [];
           captured_args = [ CR_OConstant (CR_IntLit "1", i64_ty) ];
           initializer_fn = None;
         })
  in
  let partial = make_var 15 "p" (arrow_ty [ i64_ty; i64_ty ] i64_ty) in
  let pstmt =
    make_stmt 150
      (CR_Partial_apply
         {
           dst = partial;
           closure = clos;
           new_args = [ CR_OConstant (CR_IntLit "2", i64_ty) ];
         })
  in
  let result = make_var 20 "r" i64_ty in
  let apply =
    make_stmt 200
      (CR_Call
         {
           dst = result;
           target = Apply { closure = partial };
           args = [ CR_OConstant (CR_IntLit "3", i64_ty) ];
         })
  in
  let prog =
    make_prog [ make_fn "test" [ make_block [ make; pstmt; apply ] ] ]
  in
  print_prog "test_node_dispatch_possibilities" prog;
  let t = CG.analyze prog in
  Printf.printf "--- test_node_dispatch_possibilities: result\n";
  pp_closures t

let test_non_generic () =
  let clos_ty = arrow_ty [ i64_ty ] i64_ty in
  let clos = make_var 10 "c" clos_ty in
  let make =
    make_stmt 100
      (CR_Make_closure
         {
           dst = clos;
           fn = "Test.add";
           free_vars = [];
           captured_args = [];
           initializer_fn = None;
         })
  in
  let result = make_var 20 "r" i64_ty in
  let apply =
    make_stmt 200
      (CR_Call
         {
           dst = result;
           target = Apply { closure = clos };
           args = [ CR_OConstant (CR_IntLit "42", i64_ty) ];
         })
  in
  let prog = make_prog [ make_fn "test" [ make_block [ make; apply ] ] ] in
  print_prog "test_non_generic" prog;
  let t = CG.analyze prog in
  Printf.printf "--- test_non_generic: result\n";
  pp_closures t

let test_generic_via_varying_ret_ty () =
  let clos_ty = arrow_ty [ i64_ty; i64_ty ] i64_ty in
  let clos = make_var 10 "c" clos_ty in
  let make =
    make_stmt 100
      (CR_Make_closure
         {
           dst = clos;
           fn = "Test.add";
           free_vars = [];
           captured_args = [];
           initializer_fn = None;
         })
  in
  let r1 = make_var 20 "r1" i64_ty in
  let apply1 =
    make_stmt 200
      (CR_Call
         {
           dst = r1;
           target = Apply { closure = clos };
           args =
             [
               CR_OConstant (CR_IntLit "3", i64_ty);
               CR_OConstant (CR_IntLit "4", i64_ty);
             ];
         })
  in
  let r2 = make_var 30 "r2" double_ty in
  let apply2 =
    make_stmt 300
      (CR_Call
         {
           dst = r2;
           target = Apply { closure = clos };
           args =
             [
               CR_OConstant (CR_IntLit "1", double_ty);
               CR_OConstant (CR_IntLit "2", double_ty);
             ];
         })
  in
  let prog =
    make_prog [ make_fn "test" [ make_block [ make; apply1; apply2 ] ] ]
  in
  print_prog "test_generic_via_varying_ret_ty" prog;
  let t = CG.analyze prog in
  Printf.printf "--- test_generic_via_varying_ret_ty: result\n";
  pp_closures t

let test_generic_via_from_arg_fn () =
  let clos_param = make_var 10 "f" (arrow_ty [ i64_ty ] i64_ty) in
  let result = make_var 20 "r" i64_ty in
  let apply =
    make_stmt 100
      (CR_Call
         {
           dst = result;
           target = Apply { closure = clos_param };
           args = [ CR_OConstant (CR_IntLit "42", i64_ty) ];
         })
  in
  let prog = make_prog [ make_fn "test" [ make_block [ apply ] ] ] in
  print_prog "test_generic_via_from_arg_fn" prog;
  let t = CG.analyze prog in
  Printf.printf "--- test_generic_via_from_arg_fn: result\n";
  pp_closures t

let test_generic_via_from_arg_fn_chain () =
  let clos_param = make_var 10 "f" (arrow_ty [ i64_ty ] i64_ty) in
  let moved = make_var 15 "m" (arrow_ty [ i64_ty ] i64_ty) in
  let move_stmt =
    make_stmt 100
      (CR_Assign
         {
           dst = moved;
           rvalue =
             {
               id = 101;
               node = CR_Move { src = CR_OVar clos_param };
               ty = clos_param.ty;
             };
         })
  in
  let result = make_var 20 "r" i64_ty in
  let apply =
    make_stmt 200
      (CR_Call
         {
           dst = result;
           target = Apply { closure = moved };
           args = [ CR_OConstant (CR_IntLit "42", i64_ty) ];
         })
  in
  let prog = make_prog [ make_fn "test" [ make_block [ move_stmt; apply ] ] ] in
  print_prog "test_generic_via_from_arg_fn_chain" prog;
  let t = CG.analyze prog in
  Printf.printf "--- test_generic_via_from_arg_fn_chain: result\n";
  pp_closures t

let test_cast_dispatch_possibilities () =
  let clos = make_var 10 "c" (arrow_ty [ i64_ty; i64_ty ] i64_ty) in
  let make =
    make_stmt 100
      (CR_Make_closure
         {
           dst = clos;
           fn = "Test.add";
           free_vars = [];
           captured_args = [];
           initializer_fn = None;
         })
  in
  let cast1_ty = arrow_ty [ double_ty; i64_ty ] i64_ty in
  let cast1 = make_var 15 "c1" cast1_ty in
  let cast1_stmt =
    make_stmt 150
      (CR_Assign
         {
           dst = cast1;
           rvalue =
             {
               id = 151;
               node = CR_Cast { src = CR_OVar clos; to_ty = cast1_ty };
               ty = cast1_ty;
             };
         })
  in
  let r1 = make_var 20 "r1" i64_ty in
  let apply1 =
    make_stmt 200
      (CR_Call
         {
           dst = r1;
           target = Apply { closure = cast1 };
           args =
             [
               CR_OConstant (CR_IntLit "1", double_ty);
               CR_OConstant (CR_IntLit "2", i64_ty);
             ];
         })
  in
  let cast2_ty = arrow_ty [ i64_ty; i64_ty ] i64_ty in
  let cast2 = make_var 25 "c2" cast2_ty in
  let cast2_stmt =
    make_stmt 250
      (CR_Assign
         {
           dst = cast2;
           rvalue =
             {
               id = 251;
               node = CR_Cast { src = CR_OVar clos; to_ty = cast2_ty };
               ty = cast2_ty;
             };
         })
  in
  let r2 = make_var 30 "r2" i64_ty in
  let apply2 =
    make_stmt 300
      (CR_Call
         {
           dst = r2;
           target = Apply { closure = cast2 };
           args =
             [
               CR_OConstant (CR_IntLit "3", i64_ty);
               CR_OConstant (CR_IntLit "4", i64_ty);
             ];
         })
  in
  let prog =
    make_prog
      [
        make_fn "test"
          [ make_block [ make; cast1_stmt; apply1; cast2_stmt; apply2 ] ];
      ]
  in
  print_prog "test_cast_dispatch_possibilities" prog;
  let t = CG.analyze prog in
  Printf.printf "--- test_cast_dispatch_possibilities: result\n";
  pp_closures t

let () =
  test_make_closure_node ();
  Printf.printf "\n";
  test_make_closure_with_captured ();
  Printf.printf "\n";
  test_chain_make_closure_apply ();
  Printf.printf "\n";
  test_partial_apply_closure ();
  Printf.printf "\n";
  test_dispatch_edge_weight ();
  Printf.printf "\n";
  test_node_dispatch_possibilities ();
  Printf.printf "\n";
  test_non_generic ();
  Printf.printf "\n";
  test_generic_via_varying_ret_ty ();
  Printf.printf "\n";
  test_generic_via_from_arg_fn ();
  Printf.printf "\n";
  test_generic_via_from_arg_fn_chain ();
  Printf.printf "\n";
  test_cast_dispatch_possibilities ()
