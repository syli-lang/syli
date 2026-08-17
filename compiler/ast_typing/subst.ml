open Typed_ast
open Syli_common

type t = ty IntMap.t

let empty = IntMap.empty
let bind v t s = IntMap.add v t s

let rec apply (s : t) (t : ty) : ty =
  match t.ty_desc with
  | Ty_Var { variable = Some v; _ } -> (
      match IntMap.find_opt v s with Some t' -> apply s t' | None -> t)
  | Ty_Var { variable = None; _ } -> t
  | Ty_Arrow (args, ret) ->
      { t with ty_desc = Ty_Arrow (List.map (apply s) args, apply s ret) }
  | Ty_Tuple elems -> { t with ty_desc = Ty_Tuple (List.map (apply s) elems) }
  | Ty_Array elem -> { t with ty_desc = Ty_Array (apply s elem) }
  | Ty_Ref elem -> { t with ty_desc = Ty_Ref (apply s elem) }
  | Ty_Defined d ->
      {
        t with
        ty_desc = Ty_Defined { d with args = List.map (apply s) d.args };
      }
  | Ty_Constant _ | Ty_Any -> t

let compose (s1 : t) (s2 : t) : t =
  let s2' = IntMap.map (apply s1) s2 in
  IntMap.union (fun _ l _ -> Some l) s1 s2'
