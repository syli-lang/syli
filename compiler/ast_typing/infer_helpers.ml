open Typed_ast
open Env
open Ty
open Syli_common

let fresh_ty (ctx : infer_ctx) : infer_ctx * ty =
  let v = Syli_parsing.Ast.fresh_id () in
  (ctx, { ty_desc = TTy_Var v })

let rec matching_param_to_arg (fn_params : 'a list) (args : 'b list) :
    'a list * 'b list * 'a list * 'b list =
  match (fn_params, args) with
  | [], [] -> ([], [], [], [])
  | remaining_fn, [] -> ([], [], remaining_fn, [])
  | [], remaining_arg -> ([], [], [], remaining_arg)
  | fn_param :: fn_rest, arg :: arg_rest ->
      let matched_fn, matched_arg, rest_fn, rest_arg =
        matching_param_to_arg fn_rest arg_rest
      in
      (fn_param :: matched_fn, arg :: matched_arg, rest_fn, rest_arg)

let instantiate_scheme (ctx : infer_ctx) (s : scheme) : infer_ctx * ty =
  let rec subst (m : ty IntMap.t) (t : ty) : ty =
    match t.ty_desc with
    | TTy_Var v -> ( match IntMap.find_opt v m with Some tv -> tv | None -> t)
    | TTy_Arrow (args, ret) ->
        { ty_desc = TTy_Arrow (List.map (subst m) args, subst m ret) }
    | TTy_Tuple elems -> { ty_desc = TTy_Tuple (List.map (subst m) elems) }
    | TTy_Array elem -> { ty_desc = TTy_Array (subst m elem) }
    | TTy_Defined d ->
        { ty_desc = TTy_Defined { d with args = List.map (subst m) d.args } }
    | TTy_Constant _ | TTy_Any -> t
  in
  if s.vars = [] then (ctx, Ty.apply_ty ctx s.body)
  else
    let base = Ty.apply_ty ctx s.body in
    let ctx, m =
      List.fold_left
        (fun (ctx, m) v ->
          let ctx, tv = fresh_ty ctx in
          (ctx, IntMap.add v tv m))
        (ctx, IntMap.empty) s.vars
    in
    (ctx, subst m base)
