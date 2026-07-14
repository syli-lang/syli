open Syli_ir.Oir
open Syli_common

let fresh_id = Syli_ir.Oir.fresh_id
let i64_ty : ty = { id = fresh_id (); ir_type = OR_I64 }
let void_ty : ty = { id = fresh_id (); ir_type = OR_Void }
let fn_ptr_ty : ty = { id = fresh_id (); ir_type = OR_FnPtr }
let ptr_ty (inner : ty) : ty = { id = fresh_id (); ir_type = OR_Ptr inner }
let void_ptr_ty () : ty = ptr_ty { id = fresh_id (); ir_type = OR_Void }
let fresh_var name ty : var = { id = fresh_id (); name; ty }

let int_operand (value : int) : operand =
  OR_OConstant (OR_IntLit (string_of_int value), i64_ty)

let null_operand (ty : ty) : operand = OR_OConstant (OR_Null, ty)
let make_rvalue node ty : rvalue = { id = fresh_id (); node; ty }
let make_statement node ty : statement = { id = fresh_id (); node; ty }

let operand_ty (op : operand) : ty =
  match op with OR_OConstant (_, ty) -> ty | OR_OVar v -> v.ty

let rec type_key_of_ty (t : ty) : string =
  match t.ir_type with
  | OR_Bool -> "bool"
  | OR_I64 -> "i64"
  | OR_I32 -> "i32"
  | OR_I16 -> "i16"
  | OR_I8 -> "i8"
  | OR_U64 -> "u64"
  | OR_U32 -> "u32"
  | OR_U16 -> "u16"
  | OR_U8 -> "u8"
  | OR_Float -> "f32"
  | OR_Double -> "f64"
  | OR_FnPtr -> "fn_ptr"
  | OR_Void -> "void"
  | OR_Ptr inner -> "ptr_" ^ type_key_of_ty inner
  | OR_Obj { named; args } ->
      let name = match named with Some n -> n | None -> "obj" in
      if args = [] then "obj_" ^ name
      else
        "obj_" ^ name ^ "_" ^ String.concat "_" (List.map type_key_of_ty args)

(* Partial closure accum dispatch name: shared per (closure_size, args_count) *)
let partial_closure_accum_dispatch_name ~(stored_args_size : int)
    ~(args_size : int) ~(ret_ty : ty) : string =
  Printf.sprintf "__partial_closure_accum.dispatch.clos%d_arg%d_ret_%s"
    stored_args_size args_size (type_key_of_ty ret_ty)

(** Accumulator function for Partial_apply. Layout:
    - clos[0]=accum,
    - clos[1]=parent,
    - clos[2]=dispatch_edge,
    - clos[3+]=stored_args

    Params: (args_from_child..., clos, dispatch_id) Loads stored args from
    clos[3+], chains to parent[0] with dispatch_id passed through. *)
let build_partial_closure_accum_dispatch ~(stored_args_size : int)
    ~(args_size : int) (result_ty : ty) : function_oir =
  let fn_name =
    partial_closure_accum_dispatch_name ~stored_args_size ~args_size
      ~ret_ty:result_ty
  in
  let clos_ty = ptr_ty void_ty in
  let clos_var = fresh_var "Sy_clos" (ptr_ty void_ty) in
  let dispatch_param = fresh_var "Sy_dp_id" i64_ty in
  let arg_params =
    List.init args_size (fun i -> fresh_var ("Sy_x" ^ string_of_int i) i64_ty)
  in
  let dispatch_clos_var = fresh_var "Sy_dp_clos" i64_ty in
  let load_dispatch_stmt =
    make_statement
      (OR_Assign
         {
           dst = dispatch_clos_var;
           rvalue =
             make_rvalue
               (OR_Object_get
                  {
                    obj = OR_OVar clos_var;
                    field_idx = int_operand 1;
                    value_ty = i64_ty;
                  })
               i64_ty;
         })
      i64_ty
  in
  let accum_dispatch_id_var = fresh_var "Sy_accum_dp_id" i64_ty in
  let accum_dispatch_id_stmt =
    make_statement
      (OR_Assign
         {
           dst = accum_dispatch_id_var;
           rvalue =
             make_rvalue
               (OR_BinOp
                  {
                    op = OR_Add;
                    lhs = OR_OVar dispatch_param;
                    rhs = OR_OVar dispatch_clos_var;
                  })
               i64_ty;
         })
      i64_ty
  in
  let parent_clos_var = fresh_var "Sy_p_clos" clos_ty in
  let load_parent_stmt =
    make_statement
      (OR_Assign
         {
           dst = parent_clos_var;
           rvalue =
             make_rvalue
               (OR_Object_get
                  {
                    obj = OR_OVar clos_var;
                    field_idx = int_operand 2;
                    value_ty = clos_ty;
                  })
               clos_ty;
         })
      clos_ty
  in
  let parent_accum_var = fresh_var "Sy_p_accum" fn_ptr_ty in
  let load_parent_accum_stmt =
    make_statement
      (OR_Assign
         {
           dst = parent_accum_var;
           rvalue =
             make_rvalue
               (OR_Object_get
                  {
                    obj = OR_OVar parent_clos_var;
                    field_idx = int_operand 0;
                    value_ty = fn_ptr_ty;
                  })
               fn_ptr_ty;
         })
      fn_ptr_ty
  in
  let stored_vars, stored_load_stmts =
    List.init stored_args_size (fun i ->
        let sv = fresh_var ("Sy_val" ^ string_of_int i) i64_ty in
        let load_stmt =
          make_statement
            (OR_Assign
               {
                 dst = sv;
                 rvalue =
                   make_rvalue
                     (OR_Object_get
                        {
                          obj = OR_OVar clos_var;
                          field_idx = int_operand (3 + i);
                          value_ty = i64_ty;
                        })
                     i64_ty;
               })
            i64_ty
        in
        (sv, load_stmt))
    |> List.split
  in
  let dst_var = fresh_var "Sy_rst" result_ty in
  let return_term =
    { id = fresh_id (); node = OR_Return (Some (OR_OVar dst_var)) }
  in
  let call_stmt =
    make_statement
      (OR_Call
         {
           dst = dst_var;
           target = Direct_fn_ptr { ptr = parent_accum_var };
           args =
             List.map (fun v -> OR_OVar v) (stored_vars @ arg_params)
             @ [ OR_OVar parent_clos_var; OR_OVar accum_dispatch_id_var ];
         })
      dst_var.ty
  in
  let entry_block =
    {
      id = fresh_id ();
      label_id = 0;
      statements =
        [
          load_dispatch_stmt;
          accum_dispatch_id_stmt;
          load_parent_stmt;
          load_parent_accum_stmt;
        ]
        @ stored_load_stmts @ [ call_stmt ];
      terminator = return_term;
      pred_blocks = [];
      succ_blocks = [];
    }
  in
  let locals =
    [
      dst_var;
      dispatch_clos_var;
      dispatch_param;
      parent_clos_var;
      parent_accum_var;
    ]
    @ stored_vars
  in
  {
    id = fresh_id ();
    name = fn_name;
    params = arg_params @ [ clos_var; dispatch_param ];
    locals;
    entry_block;
    blocks = [ entry_block ];
    return_ty = result_ty;
    visibility = OR_Private;
  }

(* Partial closure accum name: shared per (closure_size, args_count) *)
let partial_closure_accum_name ~(stored_args_size : int) ~(args_size : int)
    ~(ret_ty : ty) : string =
  Printf.sprintf "__partial_closure_accum.clos%d_arg%d_ret_%s" stored_args_size
    args_size (type_key_of_ty ret_ty)

(** Accumulator function for Partial_apply. Layout:
    - clos[0]=accum,
    - clos[1]=parent,
    - clos[2+]=stored_args

    Params: (args_from_child..., clos, dispatch_id) Loads stored args from
    clos[3+], chains to parent[0]. *)
let build_partial_closure_accum ~(stored_args_size : int) ~(args_size : int)
    (result_ty : ty) : function_oir =
  let fn_name =
    partial_closure_accum_name ~stored_args_size ~args_size ~ret_ty:result_ty
  in
  let clos_var = fresh_var "Sy_clos" (ptr_ty void_ty) in
  let dispatch_param = fresh_var "Sy_dp_id" i64_ty in
  let closure_ptr_ty = ptr_ty void_ty in
  let arg_params =
    List.init args_size (fun i -> fresh_var ("Sy_x" ^ string_of_int i) i64_ty)
  in
  let parent_clos_var = fresh_var "Sy_p_clos" closure_ptr_ty in
  let load_parent_stmt =
    make_statement
      (OR_Assign
         {
           dst = parent_clos_var;
           rvalue =
             make_rvalue
               (OR_Object_get
                  {
                    obj = OR_OVar clos_var;
                    field_idx = int_operand 1;
                    value_ty = closure_ptr_ty;
                  })
               closure_ptr_ty;
         })
      closure_ptr_ty
  in
  let parent_accum_var = fresh_var "Sy_p_accum" fn_ptr_ty in
  let load_parent_accum_stmt =
    make_statement
      (OR_Assign
         {
           dst = parent_accum_var;
           rvalue =
             make_rvalue
               (OR_Object_get
                  {
                    obj = OR_OVar parent_clos_var;
                    field_idx = int_operand 0;
                    value_ty = fn_ptr_ty;
                  })
               fn_ptr_ty;
         })
      fn_ptr_ty
  in
  let stored_vars, stored_load_stmts =
    List.init stored_args_size (fun i ->
        let sv = fresh_var ("Sy_val" ^ string_of_int i) i64_ty in
        let load_stmt =
          make_statement
            (OR_Assign
               {
                 dst = sv;
                 rvalue =
                   make_rvalue
                     (OR_Object_get
                        {
                          obj = OR_OVar clos_var;
                          field_idx = int_operand (2 + i);
                          value_ty = i64_ty;
                        })
                     i64_ty;
               })
            i64_ty
        in
        (sv, load_stmt))
    |> List.split
  in
  let dst_var = fresh_var "Sy_rst" result_ty in
  let return_term =
    { id = fresh_id (); node = OR_Return (Some (OR_OVar dst_var)) }
  in
  let call_stmt =
    make_statement
      (OR_Call
         {
           dst = dst_var;
           target = Direct_fn_ptr { ptr = parent_accum_var };
           args =
             List.map (fun v -> OR_OVar v) (stored_vars @ arg_params)
             @ [ OR_OVar parent_clos_var; OR_OVar dispatch_param ];
         })
      dst_var.ty
  in
  let entry_block =
    {
      id = fresh_id ();
      label_id = 0;
      statements =
        [ load_parent_stmt; load_parent_accum_stmt ]
        @ stored_load_stmts @ [ call_stmt ];
      terminator = return_term;
      pred_blocks = [];
      succ_blocks = [];
    }
  in
  let locals =
    [ dst_var; dispatch_param; parent_clos_var; parent_accum_var ] @ stored_vars
  in
  {
    id = fresh_id ();
    name = fn_name;
    params = arg_params @ [ clos_var; dispatch_param ];
    locals;
    entry_block;
    blocks = [ entry_block ];
    return_ty = result_ty;
    visibility = OR_Private;
  }

(* Helper: build a block with a Return terminator *)
let return_block (label_id : int) (stmts : statement list) (ret_val : var) :
    block =
  {
    id = fresh_id ();
    label_id;
    statements = stmts;
    terminator = { id = fresh_id (); node = OR_Return (Some (OR_OVar ret_val)) };
    pred_blocks = [];
    succ_blocks = [];
  }

(* Helper: generate cast statements for a list of arg vars *)
let gen_casts (prefix : string) (arg_vars : var list) (param_tys : ty list) :
    var list * statement list =
  let pairs =
    List.mapi
      (fun i (av : var) ->
        let cv = fresh_var (prefix ^ string_of_int i) (List.nth param_tys i) in
        let cast_stmt =
          make_statement
            (OR_Assign
               {
                 dst = cv;
                 rvalue =
                   make_rvalue
                     (OR_Cast { src = OR_OVar av; to_ty = cv.ty })
                     cv.ty;
               })
            cv.ty
        in
        (cv, cast_stmt))
      arg_vars
  in
  (List.map fst pairs, List.map snd pairs)

let apply_wrapper_name ~(fn_name : string) ~param_tys ~ret_ty : qualified_name =
  let param_tys = List.map type_key_of_ty param_tys in
  Printf.sprintf "__wrapper.%s.%s_ret_%s" fn_name
    (String.concat "_" param_tys)
    (type_key_of_ty ret_ty)

(*
   Build a __wrapper function.
   Signature: (all_args...) -> ret_ty
   Body: cast each arg from i64 to param_tys[i], call fn_name(casted_args...)
   Generated once per unique (fn_name, param_tys, ret_ty).
*)
let build_apply_wrapper ~(fn_name : string) ~(param_tys : ty list)
    ~(ret_ty : ty) : function_oir =
  let wrapper_name = apply_wrapper_name ~fn_name ~param_tys ~ret_ty in
  let arg_params =
    List.mapi (fun i _ -> fresh_var ("Sy_x" ^ string_of_int i) i64_ty) param_tys
  in
  let cast_vars, cast_stmts = gen_casts "Sy_s" arg_params param_tys in
  let casted_args = List.map (fun v -> OR_OVar v) cast_vars in
  let dst_var = fresh_var "Sy_rst" ret_ty in
  let callee_name =
    let suffix = String.concat "__" (List.map type_key_of_ty param_tys) in
    if suffix = "" then fn_name
    else fn_name ^ "__" ^ suffix ^ "_ret_" ^ type_key_of_ty ret_ty
  in
  let call_stmt =
    make_statement
      (OR_Call
         { dst = dst_var; target = Direct callee_name; args = casted_args })
      ret_ty
  in
  let entry_block = return_block 0 (cast_stmts @ [ call_stmt ]) dst_var in
  {
    id = fresh_id ();
    name = wrapper_name;
    params = arg_params;
    locals = dst_var :: cast_vars;
    entry_block;
    blocks = [ entry_block ];
    return_ty = ret_ty;
    visibility = OR_Private;
  }

let apply_wrapper_name_cast ~(fn_name : string) ~(param_tys : ty list)
    ~(cast_from : ty) : qualified_name =
  let param_tys = List.map type_key_of_ty param_tys in
  Printf.sprintf "__wrapper.%s.%s_cast_%s_ret_%s" fn_name
    (String.concat "_" param_tys)
    (type_key_of_ty cast_from) (type_key_of_ty i64_ty)

let build_apply_wrapper_cast ~(fn_name : string) ~(param_tys : ty list)
    ~(cast_from : ty) : function_oir =
  let wrapper_name = apply_wrapper_name_cast ~fn_name ~param_tys ~cast_from in
  let arg_params =
    List.mapi (fun i _ -> fresh_var ("Sy_x" ^ string_of_int i) i64_ty) param_tys
  in
  let cast_vars, cast_stmts = gen_casts "Sy_s" arg_params param_tys in
  let casted_args = List.map (fun v -> OR_OVar v) cast_vars in
  let dst_var = fresh_var "Sy_rst" cast_from in
  let callee_name =
    let suffix = String.concat "__" (List.map type_key_of_ty param_tys) in
    if suffix = "" then fn_name
    else fn_name ^ "__" ^ suffix ^ "_ret_" ^ type_key_of_ty cast_from
  in
  let call_stmt =
    make_statement
      (OR_Call
         { dst = dst_var; target = Direct callee_name; args = casted_args })
      cast_from
  in
  let result_var = fresh_var "Sy_result" i64_ty in
  let cast_result_stmt =
    make_statement
      (OR_Assign
         {
           dst = result_var;
           rvalue =
             make_rvalue
               (OR_Cast { src = OR_OVar dst_var; to_ty = i64_ty })
               i64_ty;
         })
      i64_ty
  in
  let entry_block =
    return_block 0 (cast_stmts @ [ call_stmt; cast_result_stmt ]) result_var
  in
  {
    id = fresh_id ();
    name = wrapper_name;
    params = arg_params;
    locals = (dst_var :: cast_vars) @ [ result_var ];
    entry_block;
    blocks = [ entry_block ];
    return_ty = i64_ty;
    visibility = OR_Private;
  }

let make_closure_accum_dispatch_name (id : int) ~(ret_ty : ty) : qualified_name
    =
  Printf.sprintf "__make_closure_accum.dispatch.%d_ret_%s" id
    (type_key_of_ty ret_ty)

(*
   Build a make_closure_accum_dispatch function (multi-path).
   Signature: (all_remaining_args..., clos, dispatch_id) -> ret_ty
   Body: load stored args from clos[1+], combine with remaining_args,
         switch on dispatch_id, each case calls the corresponding
         __wrapper with all m args.

     Closure Layout:
     - clos[0]  = __make_closure_accum_dispatch,
     - clos[1+] = stored_args
*)
let build_make_closure_accum_dispatch ~stored_args_size ~args_size
    ~(specializations : (int * string * ty list * ty) list) ~ret_ty id :
    function_oir =
  let dispatch_accum_fn_name = make_closure_accum_dispatch_name id ~ret_ty in
  let apply_arg_params =
    List.init args_size (fun i -> fresh_var ("Sy_x" ^ string_of_int i) i64_ty)
  in
  let clos_ty = ptr_ty void_ty in
  let clos_var = fresh_var "Sy_clos" clos_ty in
  let dispatch_param = fresh_var "Sy_dp_id" i64_ty in
  (* Load stored args from clos[1+] *)
  let stored_vars, stored_load_stmts =
    List.init stored_args_size (fun i ->
        let sv = fresh_var ("Sy_val" ^ string_of_int i) i64_ty in
        let load_stmt =
          make_statement
            (OR_Assign
               {
                 dst = sv;
                 rvalue =
                   make_rvalue
                     (OR_Object_get
                        {
                          obj = OR_OVar clos_var;
                          field_idx = int_operand (1 + i);
                          value_ty = i64_ty;
                        })
                     i64_ty;
               })
            i64_ty
        in
        (sv, load_stmt))
    |> List.split
  in
  let all_arg_vars = stored_vars @ apply_arg_params in
  (* For each case, generate a block that calls the direct wrapper *)
  let case_data =
    List.map
      (fun (tag_id, fn_name, param_tys, spe_ret_ty) ->
        let direct_fn =
          if type_key_of_ty spe_ret_ty = type_key_of_ty ret_ty then
            apply_wrapper_name ~fn_name ~param_tys ~ret_ty
          else apply_wrapper_name_cast ~fn_name ~param_tys ~cast_from:spe_ret_ty
        in
        let case_dst =
          fresh_var ("Sy_case_result" ^ string_of_int tag_id) ret_ty
        in
        let call_stmt =
          make_statement
            (OR_Call
               {
                 dst = case_dst;
                 target = Direct direct_fn;
                 args = List.map (fun v -> OR_OVar v) all_arg_vars;
               })
            ret_ty
        in
        let blk = return_block tag_id [ call_stmt ] case_dst in
        (blk, [ case_dst ], { value = tag_id; target_block = blk.id }))
      specializations
  in
  let case_blocks = List.map (fun (b, _, _) -> b) case_data in
  let case_locals = List.concat_map (fun (_, l, _) -> l) case_data in
  let cases = List.map (fun (_, _, c) -> c) case_data in
  let entry_block =
    {
      id = fresh_id ();
      label_id = -1;
      statements = stored_load_stmts;
      terminator =
        {
          id = fresh_id ();
          node =
            OR_Switch
              { scrutinee = dispatch_param; cases; default_block = None };
        };
      pred_blocks = [];
      succ_blocks = [];
    }
  in
  let all_blocks = entry_block :: case_blocks in
  {
    id = fresh_id ();
    name = dispatch_accum_fn_name;
    params = apply_arg_params @ [ clos_var; dispatch_param ];
    locals = stored_vars @ case_locals;
    entry_block;
    blocks = all_blocks;
    return_ty = ret_ty;
    visibility = OR_Private;
  }

let make_closure_accum_name ~(fn_name : string) (id : int) ~(ret_ty : ty) :
    qualified_name =
  Printf.sprintf "__make_closure_accum.%s.%d_ret_%s" fn_name id
    (type_key_of_ty ret_ty)

(** Build a make_closure_accum function. Signature: (all_remaining_args...,
    clos, dispatch_id) -> ret_ty Body: load stored args from clos[1+], combine
    with remaining_args, call the corresponding __wrapper with all m args.

    Closure layout:
    - clos[0] = __make_closure_accum,
    - clos[1+] = stored_args *)
let build_make_closure_accum ~(fn_name : string) ~stored_args_size ~args_size
    ~(specializations : ty list) ~ret_ty id : function_oir =
  let accum_fn_name = make_closure_accum_name ~fn_name id ~ret_ty in
  let dispatch_param = fresh_var "Sy_dp_id" i64_ty in
  let clos_var = fresh_var "Sy_clos" (ptr_ty void_ty) in
  let arg_params =
    List.init args_size (fun i -> fresh_var ("Sy_x" ^ string_of_int i) i64_ty)
  in
  let stored_vars, stored_load_stmts =
    List.init stored_args_size (fun i ->
        let sv = fresh_var ("Sy_val" ^ string_of_int i) i64_ty in
        let load_stmt =
          make_statement
            (OR_Assign
               {
                 dst = sv;
                 rvalue =
                   make_rvalue
                     (OR_Object_get
                        {
                          obj = OR_OVar clos_var;
                          field_idx = int_operand (1 + i);
                          value_ty = i64_ty;
                        })
                     i64_ty;
               })
            i64_ty
        in
        (sv, load_stmt))
    |> List.split
  in
  let dst_var = fresh_var "Sy_rst" ret_ty in
  let return_term =
    { id = fresh_id (); node = OR_Return (Some (OR_OVar dst_var)) }
  in
  let specialization_name =
    apply_wrapper_name ~fn_name ~param_tys:specializations ~ret_ty
  in
  let call_stmt =
    make_statement
      (OR_Call
         {
           dst = dst_var;
           target = Direct specialization_name;
           args = List.map (fun v -> OR_OVar v) (stored_vars @ arg_params);
         })
      dst_var.ty
  in
  let entry_block =
    {
      id = fresh_id ();
      label_id = 0;
      statements = stored_load_stmts @ [ call_stmt ];
      terminator = return_term;
      pred_blocks = [];
      succ_blocks = [];
    }
  in
  let locals = dst_var :: stored_vars in
  {
    id = fresh_id ();
    name = accum_fn_name;
    params = arg_params @ [ clos_var; dispatch_param ];
    locals;
    entry_block;
    blocks = [ entry_block ];
    return_ty = ret_ty;
    visibility = OR_Private;
  }
