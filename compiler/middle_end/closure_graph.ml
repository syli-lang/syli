open Syli_ir.Cir
open Syli_common

type node_id = int

type node_kind =
  | NK_Make_closure
  | NK_Partial_apply
  | NK_Apply
  | NK_Arrow_move
  | NK_Arrow_cast

type node = {
  id : node_id;
  block_id : int;
  arg_tys : ty list;
  remaining_arg_tys : ty list;
  ret_ty : ty;
  node_kind : node_kind;
}

type root =
  | OR_Make_closure of qualified_name * node_id
  | OR_From_Arg_Fn of node_id

type summary = {
  root : root;
  acc_node_args : node_id list;
  ret_ty : ty;
  remaining_arg_tys : ty list;
  free_var_count : int;
}

type graph = {
  nodes : node IntMap.t;
  node_summaries : summary list IntMap.t;
  edges : node_id list IntMap.t;
  heads : node_id list;
  root_ids : IntSet.t;
  node_leaf_summaries : summary list IntMap.t;
  node_roots : node_id list IntMap.t;
  closure_as_arg : IntSet.t;
}

let empty : graph =
  {
    nodes = IntMap.empty;
    node_summaries = IntMap.empty;
    edges = IntMap.empty;
    heads = [];
    root_ids = IntSet.empty;
    node_leaf_summaries = IntMap.empty;
    node_roots = IntMap.empty;
    closure_as_arg = IntSet.empty;
  }

type fn_specialization = {
  fn_name : qualified_name;
  arg_tys : ty list;
  ret_ty : ty;
  dispatch_cumul : int;
}

type t = {
  graph : graph;
  closure_dispatch_ids : Closure_dispatch_id.t;
  node_dispatch_possibilities : int list IntMap.t;
  concrete_ret_ty : ty IntMap.t;
  make_closure_fn_specializations : fn_specialization list IntMap.t;
  generic_nodes : IntSet.t;
}

let is_arrow_ty (t : ty) : bool =
  match t.ir_type with CR_Arrow _ -> true | _ -> false

let extract_arrow_tys (t : ty) : (ty list * ty) option =
  match t.ir_type with
  | CR_Arrow (param_tys, ret_ty) -> Some (param_tys, ret_ty)
  | _ -> None

let operand_ty = function CR_OConstant (_, ty) -> ty | CR_OVar v -> v.ty

let rec build_graph (prog : module_cir) : graph =
  let add_root (graph : graph) node_id =
    { graph with root_ids = IntSet.add node_id graph.root_ids }
  in
  let add_edge ~(graph : graph) ~(parent_id : node_id) ~(child_id : node_id) :
      graph =
    let children =
      match IntMap.find_opt parent_id graph.edges with
      | Some ids -> child_id :: ids
      | None -> [ child_id ]
    in
    { graph with edges = IntMap.add parent_id children graph.edges }
  in
  let add_node graph block_id (dst : var) arg_tys (node_kind : node_kind) :
      graph * node =
    let remaining_arg_tys, ret_ty =
      match extract_arrow_tys dst.ty with
      | Some (r, rt) -> (r, rt)
      | None -> ([], dst.ty)
    in
    let node : node =
      { id = dst.id; block_id; arg_tys; remaining_arg_tys; ret_ty; node_kind }
    in
    ({ graph with nodes = IntMap.add dst.id node graph.nodes }, node)
  in
  let update_summaries_for_closure (g : graph) (closure : var) (node : node) =
    match IntMap.find_opt closure.id g.node_summaries with
    | None ->
        [
          {
            root = OR_From_Arg_Fn node.id;
            acc_node_args = [ node.id ];
            free_var_count = 0;
            ret_ty = node.ret_ty;
            remaining_arg_tys = node.remaining_arg_tys;
          };
        ]
    | Some summaries ->
        List.map
          (fun (s : summary) ->
            {
              s with
              acc_node_args = node.id :: s.acc_node_args;
              remaining_arg_tys = node.remaining_arg_tys;
              ret_ty = node.ret_ty;
            })
          summaries
  in
  let process_statement (graph : graph) (block_id : int) (stmt : statement) :
      graph =
    match stmt.node with
    | CR_Make_closure { dst; fn; free_vars; captured_args; _ } ->
        let free_var_tys = List.map (fun (v : var) -> v.ty) free_vars in
        let captured_arg_tys =
          free_var_tys @ List.map operand_ty captured_args
        in
        let graph, node =
          add_node graph block_id dst captured_arg_tys NK_Make_closure
        in
        let graph = add_root graph node.id in
        let free_var_count = List.length free_vars in
        let summary : summary =
          {
            root = OR_Make_closure (fn, node.id);
            acc_node_args = [ node.id ];
            free_var_count;
            ret_ty = node.ret_ty;
            remaining_arg_tys = node.remaining_arg_tys;
          }
        in
        {
          graph with
          node_summaries = IntMap.add dst.id [ summary ] graph.node_summaries;
          heads = dst.id :: graph.heads;
        }
    | CR_Partial_apply { dst; closure; new_args } ->
        let new_arg_tys = List.map operand_ty new_args in
        let graph = add_edge ~graph ~parent_id:closure.id ~child_id:dst.id in
        let graph, node =
          add_node graph block_id dst new_arg_tys NK_Partial_apply
        in
        let summaries = update_summaries_for_closure graph closure node in
        {
          graph with
          node_summaries = IntMap.add dst.id summaries graph.node_summaries;
        }
    | CR_Call { dst; target = Apply { closure }; args } ->
        let closure_as_arg =
          List.fold_left
            (fun acc operand ->
              match operand with
              | CR_OVar var ->
                  if is_arrow_ty var.ty then IntSet.add var.id acc else acc
              | _ -> acc)
            graph.closure_as_arg args
        in
        let arg_tys = List.map operand_ty args in
        let graph = add_edge ~graph ~parent_id:closure.id ~child_id:dst.id in
        let graph, node = add_node graph block_id dst arg_tys NK_Apply in
        let summaries = update_summaries_for_closure graph closure node in
        {
          graph with
          node_summaries = IntMap.add dst.id summaries graph.node_summaries;
          closure_as_arg;
        }
    | CR_Assign
        { dst; rvalue = { node = CR_Cast { src = CR_OVar c; _ }; _ }; _ }
      when is_arrow_ty dst.ty ->
        let graph = add_edge ~graph ~parent_id:c.id ~child_id:dst.id in
        let graph, node = add_node graph block_id dst [] NK_Arrow_cast in
        let child_summaries = update_summaries_for_closure graph c node in
        {
          graph with
          node_summaries =
            IntMap.add dst.id child_summaries graph.node_summaries;
        }
    | CR_Assign { dst; rvalue = { node = CR_Move { src = CR_OVar c }; _ }; _ }
      when is_arrow_ty dst.ty ->
        let graph = add_edge ~graph ~parent_id:c.id ~child_id:dst.id in
        let graph, node = add_node graph block_id dst [] NK_Arrow_move in
        let child_summaries = update_summaries_for_closure graph c node in
        (* Move is used to assign in more than once to a variable,
         so existing here make sense *)
        let existing =
          match IntMap.find_opt dst.id graph.node_summaries with
          | Some s -> s
          | None -> []
        in
        {
          graph with
          node_summaries =
            IntMap.add dst.id (existing @ child_summaries) graph.node_summaries;
        }
    | _ -> graph
  in
  let process_block (g : graph) (block : block) : graph =
    List.fold_left
      (fun g stmt -> process_statement g block.id stmt)
      g block.statements
  in
  let process_function (g : graph) (fn : function_cir) : graph =
    List.fold_left process_block g fn.blocks
  in
  let graph = List.fold_left process_function empty prog.functions in
  let leaves =
    IntMap.fold
      (fun node_id _node acc ->
        if IntMap.mem node_id graph.edges then acc else IntSet.add node_id acc)
      graph.nodes IntSet.empty
  in
  let node_leaf_summaries =
    IntMap.filter
      (fun node_id _ -> IntSet.mem node_id leaves)
      graph.node_summaries
  in
  let summaries =
    IntMap.bindings node_leaf_summaries |> List.map snd |> List.flatten
  in
  let node_roots =
    List.fold_left
      (fun acc summary ->
        let root_id =
          match summary.root with
          | OR_From_Arg_Fn node_id | OR_Make_closure (_, node_id) -> node_id
        in
        List.fold_left
          (fun acc node_id ->
            IntMap.update node_id
              (function
                | Some roots -> Option.some @@ (root_id :: roots)
                | None -> Option.some @@ [ root_id ])
              acc)
          acc summary.acc_node_args)
      IntMap.empty summaries
  in
  { graph with node_leaf_summaries; node_roots }

let dispatch_edge_weight t ~src ~target : int =
  Closure_dispatch_id.edge_weight t.closure_dispatch_ids ~src ~target

let get_node_dispatch_possibilities t node_id : int list =
  IntMap.find_opt node_id t.node_dispatch_possibilities
  |> Option.value ~default:[]

let node_dispatch_possibilities (dispatch_ids : Closure_dispatch_id.t)
    (prog : module_cir) : int list IntMap.t =
  let process_statement acc (stmt : statement) : int list IntMap.t =
    match stmt.node with
    | CR_Partial_apply { dst; closure; _ } ->
        let edge_dispatch =
          Closure_dispatch_id.edge_weight dispatch_ids ~src:closure.id
            ~target:dst.id
        in
        IntMap.update dst.id
          (fun existing ->
            Some
              (match existing with
              | Some ids -> edge_dispatch :: ids
              | None -> [ edge_dispatch ]))
          acc
    | CR_Call { dst; target = Apply { closure }; _ } ->
        let edge_dispatch =
          Closure_dispatch_id.edge_weight dispatch_ids ~src:closure.id
            ~target:dst.id
        in
        IntMap.update dst.id
          (fun existing ->
            Some
              (match existing with
              | Some ids -> edge_dispatch :: ids
              | None -> [ edge_dispatch ]))
          acc
    | CR_Assign
        { dst; rvalue = { node = CR_Cast { src = CR_OVar c; _ }; _ }; _ }
      when is_arrow_ty dst.ty ->
        let edge_dispatch =
          Closure_dispatch_id.edge_weight dispatch_ids ~src:c.id ~target:dst.id
        in
        IntMap.update dst.id
          (fun existing ->
            Some
              (match existing with
              | Some ids -> edge_dispatch :: ids
              | None -> [ edge_dispatch ]))
          acc
    | CR_Assign { dst; rvalue = { node = CR_Move { src = CR_OVar c }; _ }; _ }
      when is_arrow_ty dst.ty ->
        let edge_dispatch =
          Closure_dispatch_id.edge_weight dispatch_ids ~src:c.id ~target:dst.id
        in
        IntMap.update dst.id
          (fun existing ->
            Some
              (match existing with
              | Some ids -> edge_dispatch :: ids
              | None -> [ edge_dispatch ]))
          acc
    | _ -> acc
  in
  let process_block acc (block : block) : int list IntMap.t =
    List.fold_left
      (fun acc stmt -> process_statement acc stmt)
      acc block.statements
  in
  let process_function acc (fn : function_cir) : int list IntMap.t =
    List.fold_left process_block acc fn.blocks
    |> IntMap.map (fun x -> List.sort_uniq Int.compare x)
  in
  List.fold_left process_function IntMap.empty prog.functions

let retropopagate_ret_ty graph =
  IntMap.fold
    (fun node_id summaries tys ->
      List.fold_left
        (fun acc summary ->
          match summary.acc_node_args with
          | hd :: _ ->
              let leaf_ret_ty = summary.ret_ty in
              List.fold_left
                (fun acc node_id ->
                  let node = IntMap.find node_id graph.nodes in
                  IntMap.update node.id
                    (fun ret_ty_gen ->
                      match ret_ty_gen with
                      | Some (ret_ty, is_generic) ->
                          if
                            Helpers.type_key_of_ty ret_ty
                            <> Helpers.type_key_of_ty leaf_ret_ty
                          then Some (ret_ty, true)
                          else None
                      | None -> Some (leaf_ret_ty, false))
                    acc)
                acc summary.acc_node_args
          | _ -> acc)
        tys summaries)
    graph.node_leaf_summaries IntMap.empty
  |> IntMap.filter_map (fun _ (ret_ty, is_generic) ->
      if is_generic then None else Some ret_ty)

let generic_nodes fn_specializations graph =
  let generic_roots =
    IntMap.fold
      (fun node_id summaries acc ->
        List.fold_left
          (fun acc summary ->
            match summary.root with
            | OR_From_Arg_Fn node_id -> IntSet.add node_id acc
            | OR_Make_closure (_, node_id) -> (
                match IntMap.find_opt node_id fn_specializations with
                | None -> acc
                | Some specializations -> (
                    match specializations with
                    | [] -> acc
                    | hd :: tl ->
                        if
                          List.exists
                            (fun sp ->
                              Helpers.type_key_of_ty sp.ret_ty
                              <> Helpers.type_key_of_ty hd.ret_ty)
                            tl
                        then IntSet.add node_id acc
                        else if
                          (* the root of a summary is generic if the leaf is passed as an argument *)
                          List.exists
                            (fun node_id ->
                              IntSet.mem node_id graph.closure_as_arg)
                            summary.acc_node_args
                        then IntSet.add node_id acc
                        else acc)))
          acc summaries)
      graph.node_leaf_summaries IntSet.empty
  in
  let generic_nodes =
    IntMap.fold
      (fun node_id roots_node_ids acc ->
        if
          List.exists
            (fun node_id -> IntSet.mem node_id generic_roots)
            roots_node_ids
        then IntSet.add node_id acc
        else acc)
      graph.node_roots generic_roots
  in
  generic_nodes

let analyze (prog : module_cir) : t =
  let compute_closure_dispatch_ids t =
    let graph : Closure_dispatch_id.graph =
      { root_ids = IntSet.to_list t.root_ids; edges = t.edges }
    in
    Closure_dispatch_id.compute_dispatch_ids graph
  in
  let graph = build_graph prog in
  let closure_dispatch_ids = compute_closure_dispatch_ids graph in
  let node_dispatch_possibilities =
    node_dispatch_possibilities closure_dispatch_ids prog
  in
  let concrete_ret_ty = retropopagate_ret_ty graph in
  let make_closure_fn_specializations =
    IntMap.fold
      (fun _ summaries acc ->
        List.fold_left
          (fun acc s ->
            match s.root with
            | OR_Make_closure (fn_name, root_id) ->
                let dispatch_cumul =
                  let rec go node_ids acc =
                    match node_ids with
                    | x :: y :: tl ->
                        go (y :: tl)
                          (acc
                          + Closure_dispatch_id.edge_weight closure_dispatch_ids
                              ~src:y ~target:x)
                    | _ -> acc
                  in
                  go s.acc_node_args 0
                in
                let arg_tys =
                  (List.map
                     (fun node_id -> (IntMap.find node_id graph.nodes).arg_tys)
                     (s.acc_node_args |> List.rev)
                  |> List.flatten)
                  @ s.remaining_arg_tys
                in
                IntMap.update root_id
                  (fun existing ->
                    Some
                      ({ fn_name; arg_tys; ret_ty = s.ret_ty; dispatch_cumul }
                      :: Option.value ~default:[] existing))
                  acc
            | _ -> acc)
          acc summaries)
      graph.node_leaf_summaries IntMap.empty
  in
  let generic_nodes = generic_nodes make_closure_fn_specializations graph in
  {
    graph;
    closure_dispatch_ids;
    node_dispatch_possibilities;
    concrete_ret_ty;
    make_closure_fn_specializations;
    generic_nodes;
  }
