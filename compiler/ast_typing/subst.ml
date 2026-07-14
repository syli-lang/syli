open Typed_ast
open Syli_common

type t = ty IntMap.t

let empty = IntMap.empty
let bind v t s = IntMap.add v t s

let rec apply (s : t) (t : ty) : ty =
  match t.ty_desc with
  | TTy_Var v -> (
      match IntMap.find_opt v s with Some t' -> apply s t' | None -> t)
  | TTy_Arrow (args, ret) ->
      { ty_desc = TTy_Arrow (List.map (apply s) args, apply s ret) }
  | TTy_Tuple elems -> { ty_desc = TTy_Tuple (List.map (apply s) elems) }
  | TTy_Array elem -> { ty_desc = TTy_Array (apply s elem) }
  | TTy_Defined d ->
      { ty_desc = TTy_Defined { d with args = List.map (apply s) d.args } }
  | TTy_Constant _ | TTy_Any -> t

let compose (s1 : t) (s2 : t) : t =
  let s2' = IntMap.map (apply s1) s2 in
  IntMap.union (fun _ l _ -> Some l) s1 s2'
