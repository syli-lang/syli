open Core_ast
open Ast_visitor
open Syli_common

module FreeVar = struct
  type t = ident

  let compare (id1 : ident) (id2 : ident) =
    String.compare id1.fullname id2.fullname
end

module VarIdSet = Set.Make (FreeVar)

type closure_info = {
  id : int;
  free_vars : VarIdSet.t;
  lambda : lambda;
  is_from_arg : bool;
  arity : int;
}

type core_closure_analysis = { closure_infos : (int, closure_info) Hashtbl.t }

type visitor_ctx = {
  current_lambda_id : int option;
  local_names : StringSet.t;
  global_names : StringSet.t;
  lambda_info : (int, closure_info) Hashtbl.t;
  known_functions : int StringMap.t;
  lambda_arg_ids : (int, unit) Hashtbl.t;
}

let push_free_var (ctx : visitor_ctx) (var : ident) : unit =
  match ctx.current_lambda_id with
  | Some lambda_id -> (
      match Hashtbl.find_opt ctx.lambda_info lambda_id with
      | Some info ->
          Hashtbl.replace ctx.lambda_info lambda_id
            { info with free_vars = VarIdSet.add var info.free_vars }
      | None -> ())
  | None -> ()

let collect_global_names (prog : program_core) : StringSet.t =
  let from_items =
    List.fold_left
      (fun acc (item : structure_item) ->
        match item.structure_item_desc with
        | CStr_Let { name; _ } -> StringSet.add name.fullname acc
        | _ -> acc)
      StringSet.empty prog.structure_items
  in
  let from_sigs =
    List.fold_left
      (fun acc (sig_item : signature_item) ->
        match sig_item.signature_item_desc with
        | CSig_Fun { name; _ } -> StringSet.add name.fullname acc
        | _ -> acc)
      StringSet.empty prog.signature_items
  in
  StringSet.union from_items from_sigs

let collect_known_functions (prog : program_core) : int StringMap.t =
  let from_lets =
    List.fold_left
      (fun acc (item : structure_item) ->
        match item.structure_item_desc with
        | CStr_Let { name; value; _ } -> (
            match value.node with
            | CExp_Lambda lam ->
                StringMap.add name.fullname (List.length lam.params) acc
            | _ -> acc)
        | _ -> acc)
      StringMap.empty prog.structure_items
  in
  let from_sigs =
    List.fold_left
      (fun acc (sig_item : signature_item) ->
        match sig_item.signature_item_desc with
        | CSig_Fun { name; params; ret_ty; _ } ->
            let arity =
              match (params, ret_ty.ty_desc) with
              | [], CTy_Arrow (fn_params, _) -> List.length fn_params
              | _ -> List.length params
            in
            StringMap.add name.fullname arity acc
        | _ -> acc)
      StringMap.empty prog.signature_items
  in
  StringMap.union (fun _ v _ -> Some v) from_lets from_sigs

let run (prog : program_core) : core_closure_analysis =
  let global_names = collect_global_names prog in
  let known_functions = collect_known_functions prog in
  let lambda_info = Hashtbl.create 16 in
  let lambda_arg_ids = Hashtbl.create 16 in
  let initial_ctx =
    {
      current_lambda_id = None;
      local_names = StringSet.empty;
      global_names;
      lambda_info;
      known_functions;
      lambda_arg_ids;
    }
  in
  let visitor =
    {
      default_visitor with
      expr =
        (fun v acc e ->
          match e.node with
          | CExp_Lambda lambda ->
              let is_from_arg = Hashtbl.mem acc.lambda_arg_ids e.id in
              let outer_lambda_id = acc.current_lambda_id in
              let outer_local_names = acc.local_names in
              let inner_local_names =
                List.fold_left
                  (fun s (param : ident) -> StringSet.add param.fullname s)
                  StringSet.empty lambda.params
              in
              let function_info =
                {
                  id = e.id;
                  free_vars = VarIdSet.empty;
                  lambda;
                  is_from_arg;
                  arity = List.length lambda.params;
                }
              in
              Hashtbl.add acc.lambda_info e.id function_info;
              let acc' =
                {
                  acc with
                  current_lambda_id = Some e.id;
                  local_names = inner_local_names;
                }
              in
              let acc'' = v.expr v acc' lambda.body in
              {
                acc'' with
                current_lambda_id = outer_lambda_id;
                local_names = outer_local_names;
              }
          | CExp_Ident id ->
              if
                Option.is_some acc.current_lambda_id
                && (not (StringSet.mem id.fullname acc.local_names))
                && not (StringSet.mem id.fullname acc.global_names)
              then push_free_var acc id;
              acc
          | CExp_Apply { closure_fun; args } ->
              List.iter
                (fun arg ->
                  match arg.node with
                  | CExp_Lambda _ ->
                      Hashtbl.replace acc.lambda_arg_ids arg.id ()
                  | _ -> ())
                args;
              visit_expr_children v acc e
          | CExp_Seq exprs ->
              List.fold_left
                (fun acc' seq_e ->
                  let acc'' = v.expr v acc' seq_e in
                  match seq_e.node with
                  | CExp_Let { name; _ } ->
                      {
                        acc'' with
                        local_names =
                          StringSet.add name.fullname acc''.local_names;
                      }
                  | _ -> acc'')
                acc exprs
          | _ -> visit_expr_children v acc e);
      structure_item =
        (fun v acc d ->
          match d.structure_item_desc with
          | CStr_Let { value; _ } -> (
              match value.node with
              | CExp_Lambda lambda ->
                  let inner_local_names =
                    List.fold_left
                      (fun s (param : ident) -> StringSet.add param.fullname s)
                      StringSet.empty lambda.params
                  in
                  let function_info =
                    {
                      id = value.id;
                      free_vars = VarIdSet.empty;
                      lambda;
                      is_from_arg = false;
                      arity = List.length lambda.params;
                    }
                  in
                  Hashtbl.add acc.lambda_info value.id function_info;
                  let acc' =
                    {
                      acc with
                      current_lambda_id = Some value.id;
                      local_names = inner_local_names;
                    }
                  in
                  let acc'' = v.expr v acc' lambda.body in
                  {
                    acc'' with
                    current_lambda_id = None;
                    local_names = StringSet.empty;
                  }
              | _ -> visit_structure_item_children v acc d)
          | _ -> visit_structure_item_children v acc d);
    }
  in
  let _final_ctx = visit_program visitor initial_ctx prog in
  { closure_infos = lambda_info }
