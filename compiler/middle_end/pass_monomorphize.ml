(*
  This pass is monomorphizaiton for generic functions:

    - Generate specialized versions of generic functions based on call sites
      inside concrete functions.
    - Every new specialization will be recursively processed.

    ! Note: It starts from concrete functions:
        - Only one node is resolved in a call chain in order to resolve the chain.
        - The resolve comes early as possible, when all the types are concrete.
        - On a chain call the fn_ptr is placed before a closure escape a
          scope (function at the moment)
*)

open Syli_ir.Cir
open Syli_common
module Cfg = Syli_ir.Cfg
module Subst = Syli_ir.Generic_substitution

module Monomorphize = struct
  type ctx = {
    functions : function_cir StringMap.t;
    ffi_externs : ffi_external_function StringMap.t;
    new_function_clones : function_cir list;
    closure_graph : Closure_graph.t;
  }

  let new_function_clone ctx (fn : function_cir) =
    {
      ctx with
      new_function_clones = fn :: ctx.new_function_clones;
      functions = StringMap.add fn.name fn ctx.functions;
    }

  let find_function ctx fn_name = StringMap.find fn_name ctx.functions
  let type_of_var (v : var) = v.ty

  let first_n n lst =
    let rec aux acc i = function
      | [] -> List.rev acc
      | x :: xs -> if i < n then aux (x :: acc) (i + 1) xs else List.rev acc
    in
    aux [] 0 lst

  let last_n n lst =
    let len = List.length lst in
    let drop = max 0 (len - n) in
    let rec aux i = function
      | [] -> []
      | _ :: tl as l -> if i >= drop then l else aux (i + 1) tl
    in
    aux 0 lst

  let arg_ty_of_operand = function
    | CR_OConstant (_, ty) -> ty
    | CR_OVar v -> type_of_var v

  let rec has_generic_ir_type = function
    | CR_GenericTyp _ -> true
    | CR_Arrow (args, ret) ->
        List.exists (fun t -> has_generic_ir_type t.ir_type) args
        || has_generic_ir_type ret.ir_type
    | CR_Ptr t -> has_generic_ir_type t.ir_type
    | CR_Obj { args; _ } ->
        List.exists (fun t -> has_generic_ir_type t.ir_type) args
    | _ -> false

  let has_generic_ty (t : ty) = has_generic_ir_type t.ir_type

  let rec collect_subst subst (x_ty : ty) (y_ty : ty) =
    match (x_ty.ir_type, y_ty.ir_type) with
    | CR_GenericTyp { type_var }, _ -> Hashtbl.replace subst type_var y_ty
    | CR_Obj { args = x_args; _ }, CR_Obj { args = y_args; _ } ->
        List.iter2 (collect_subst subst) x_args y_args
    | CR_Ptr x_inner, CR_Ptr y_inner -> collect_subst subst x_inner y_inner
    | CR_Arrow (x_args, x_ret), CR_Arrow (y_args, y_ret) ->
        List.iter2 (collect_subst subst) x_args y_args;
        collect_subst subst x_ret y_ret
    | _ -> ()

  let create_subst x_tys y_tys : Subst.subst =
    let subst = Hashtbl.create 8 in
    List.iter2 (collect_subst subst) x_tys y_tys;
    Hashtbl.filter_map_inplace
      (fun _ v -> if not (has_generic_ty v) then Some v else None)
      subst;
    subst

  let specialization_name = Helpers.specialization_name

  (** Specialize [fn_name] using the full [arg_tys] and [ret_ty] from a
      closure_graph specialization. Computes the substitution first, then names
      using the substituted (concrete) types. *)
  let specialize_fn_with_tys ctx fn_name all_arg_tys dst_ty =
    match StringMap.find_opt fn_name ctx.functions with
    | None -> ctx
    | Some callee -> (
        let param_tys = List.map type_of_var callee.params in
        let ret_ty = callee.return_ty in
        let x_tys = first_n (List.length all_arg_tys) param_tys @ [ ret_ty ] in
        let y_tys = all_arg_tys @ [ dst_ty ] in
        let subst = create_subst x_tys y_tys in
        if Hashtbl.length subst = 0 then ctx
        else
          let param_tys_subst =
            List.map (Subst.apply_subst_ty subst) param_tys
          in
          let ret_subst = Subst.apply_subst_ty subst ret_ty in
          if
            List.exists has_generic_ty param_tys_subst
            || has_generic_ty ret_subst
          then ctx
          else
            let new_name =
              specialization_name fn_name param_tys_subst ret_subst
            in
            match StringMap.find_opt new_name ctx.functions with
            | Some _ -> ctx
            | None ->
                let new_fn =
                  Subst.clone_function (fresh_id ()) callee new_name subst
                in
                new_function_clone ctx new_fn)

  let is_generic_function_name (ctx : ctx) (fn_name : string) : bool =
    match StringMap.find_opt fn_name ctx.functions with
    | None -> false
    | Some (fn : function_cir) ->
        has_generic_ty fn.return_ty
        || List.exists (fun (p : var) -> has_generic_ty p.ty) fn.params

  let specialize_direct_call ctx dst fn args =
    let ffi_fn = StringMap.find_opt fn ctx.ffi_externs in
    if Option.is_some ffi_fn then
      (ctx, CR_Call { dst; target = Direct fn; args })
    else
      match StringMap.find_opt fn ctx.functions with
      | None -> failwith ("Unknown function: " ^ fn)
      | Some callee -> (
          let arg_tys = List.map arg_ty_of_operand args in
          let dst_ty = dst.ty in
          if List.exists has_generic_ty arg_tys || has_generic_ty dst_ty then
            (ctx, CR_Call { dst; target = Direct fn; args })
          else
            let new_name = specialization_name fn arg_tys dst_ty in
            let param_tys = List.map type_of_var callee.params in
            let ret_ty = callee.return_ty in
            match StringMap.find_opt new_name ctx.functions with
            | Some specialized_fn ->
                (ctx, CR_Call { dst; target = Direct specialized_fn.name; args })
            | None ->
                let x_tys = ret_ty :: param_tys in
                let y_tys = dst_ty :: arg_tys in
                let subst = create_subst x_tys y_tys in
                if Hashtbl.length subst = 0 then
                  (ctx, CR_Call { dst; target = Direct fn; args })
                else
                  let new_fn =
                    Subst.clone_function (fresh_id ()) callee new_name subst
                  in
                  let ctx = new_function_clone ctx new_fn in
                  (ctx, CR_Call { dst; target = Direct new_fn.name; args }))

  let rewrite_statement (ctx : ctx) (stmt : statement) : ctx * statement =
    let ctx, node =
      match stmt.node with
      | CR_Call { dst; target = Direct fn; args; _ } ->
          if is_generic_function_name ctx fn then
            specialize_direct_call ctx dst fn args
          else (ctx, CR_Call { dst; target = Direct fn; args })
      | CR_Make_closure { dst; free_vars; captured_args; fn } ->
          let ctx =
            IntMap.find_opt dst.id
              ctx.closure_graph.make_closure_fn_specializations
            |> Option.value ~default:[]
            |> List.fold_left
                 (fun ctx (spec : Closure_graph.fn_specialization) ->
                   if is_generic_function_name ctx spec.fn_name then
                     specialize_fn_with_tys ctx spec.fn_name spec.arg_tys
                       spec.ret_ty
                   else ctx)
                 ctx
          in
          ( ctx,
            CR_Make_closure
              { dst; free_vars; captured_args; fn; initializer_fn = None } )
      | other -> (ctx, other)
    in
    (ctx, { stmt with node })

  let rewrite_block (ctx : ctx) (block : block) : ctx * block =
    let ctx, statements =
      List.fold_left_map
        (fun ctx stmt -> rewrite_statement ctx stmt)
        ctx block.statements
    in
    (ctx, { block with statements })

  let rewrite_function (ctx : ctx) (fn : function_cir) : ctx * function_cir =
    let cfg = Cfg.build_cfg fn.blocks in
    let order =
      Cfg.get_block_order Cfg.ReversePostorder cfg fn.entry_block.id fn.blocks
    in
    let block_map = Cfg.build_block_map fn.blocks in
    let ctx, blocks =
      List.fold_left_map
        (fun ctx id ->
          let block = Hashtbl.find block_map id in
          let ctx, block = rewrite_block ctx block in
          (ctx, block))
        ctx order
    in
    let new_entry =
      Hashtbl.find (Cfg.build_block_map blocks) fn.entry_block.id
    in
    (ctx, { fn with blocks; entry_block = new_entry })

  let monomorphize (ctx : ctx) (functions : function_cir list) :
      ctx * function_cir list =
    List.fold_left_map (fun ctx fn -> rewrite_function ctx fn) ctx functions

  (** Filter out generic template functions that still have generic type params
      or return type. After monomorphization, these are dead code — all call
      sites have been redirected to specialized concrete versions. *)
  let filter_generic_functions (fns : function_cir list) : function_cir list =
    List.filter
      (fun (fn : function_cir) ->
        (not (has_generic_ty fn.return_ty))
        && List.for_all (fun (p : var) -> not (has_generic_ty p.ty)) fn.params)
      fns

  (** Filter out global values that still have generic types. After
      monomorphization, these are dead code — all references have been
      redirected to specialized concrete versions. *)
  let filter_generic_global_values (values : global_value list) :
      global_value list =
    List.filter (fun (gv : global_value) -> not (has_generic_ty gv.ty)) values
end

let monomorphize_program (ctx : Pipeline_types.cir_ctx) :
    Pipeline_types.cir_mono_ctx =
  let prog = ctx.module_cir in
  let closure_graph = Closure_graph.analyze prog in
  let functions =
    List.fold_left
      (fun map (fn : function_cir) -> StringMap.add fn.name fn map)
      StringMap.empty prog.functions
  in
  let ffi_externs =
    List.fold_left
      (fun map (ffi_fn : ffi_external_function) ->
        StringMap.add ffi_fn.syli_name ffi_fn map)
      StringMap.empty prog.ffi_external_functions
  in
  let ctx : Monomorphize.ctx =
    { functions; ffi_externs; new_function_clones = []; closure_graph }
  in
  let rec monomorphize ctx functions acc =
    let ctx, functions = Monomorphize.monomorphize ctx functions in
    let acc = acc @ functions in
    if List.length ctx.new_function_clones > 0 then
      let functions = ctx.new_function_clones in
      let ctx = { ctx with new_function_clones = [] } in
      monomorphize ctx functions acc
    else acc
  in
  let functions = monomorphize ctx prog.functions [] in
  let functions = Monomorphize.filter_generic_functions functions in
  let global_values =
    Monomorphize.filter_generic_global_values prog.global_values
  in
  let prog = { prog with functions; global_values } in
  let closure_graph = Closure_graph.analyze prog in
  { Pipeline_types.module_cir = prog; closure_graph }
