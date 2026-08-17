open Typed_ast
open Env
open Ty
open Syli_common

let fresh_ty (ctx : infer_ctx) : infer_ctx * ty =
  let v = Syli_parsing.Ast.fresh_id () in
  (ctx, mk_ty (Ty_Var { label = ""; variable = Some v }))

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
    | Ty_Var { variable = Some v; _ } -> (
        match IntMap.find_opt v m with Some tv -> tv | None -> t)
    | Ty_Var { variable = None; _ } -> t
    | Ty_Arrow (args, ret) ->
        { t with ty_desc = Ty_Arrow (List.map (subst m) args, subst m ret) }
    | Ty_Tuple elems -> { t with ty_desc = Ty_Tuple (List.map (subst m) elems) }
    | Ty_Array elem -> { t with ty_desc = Ty_Array (subst m elem) }
    | Ty_Ref elem -> { t with ty_desc = Ty_Ref (subst m elem) }
    | Ty_Defined d ->
        {
          t with
          ty_desc = Ty_Defined { d with args = List.map (subst m) d.args };
        }
    | Ty_Constant _ | Ty_Any -> t
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
