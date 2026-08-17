open Typed_ast
open Env

let dummy_location = { start_pos = 0; end_pos = 0; filename = "" }
let mk_ty ty_desc = { id = 0; ty_desc; loc = dummy_location }

let string_of_const_ty = function
  | Ty_Int8 -> "int8"
  | Ty_Int16 -> "int16"
  | Ty_Int32 -> "int32"
  | Ty_Int64 -> "int64"
  | Ty_UInt8 -> "uint8"
  | Ty_UInt16 -> "uint16"
  | Ty_UInt32 -> "uint32"
  | Ty_UInt64 -> "uint64"
  | Ty_Bool -> "bool"
  | Ty_Unit -> "unit"
  | Ty_Float -> "float"
  | Ty_Double -> "double"
  | Ty_StringLit -> "str"
  | Ty_CharLit -> "char"

let rec string_of_ty (t : ty) : string =
  match t.ty_desc with
  | Ty_Var { variable = Some v; _ } -> Printf.sprintf "'%d" v
  | Ty_Var { label; variable = None } -> "'" ^ label
  | Ty_Any -> "_"
  | Ty_Constant c -> string_of_const_ty c
  | Ty_Arrow (args, ret) ->
      Printf.sprintf "(%s) -> %s"
        (String.concat ", " (List.map string_of_ty args))
        (string_of_ty ret)
  | Ty_Tuple elems ->
      Printf.sprintf "(%s)" (String.concat " * " (List.map string_of_ty elems))
  | Ty_Array elem -> Printf.sprintf "array<%s>" (string_of_ty elem)
  | Ty_Ref elem -> Printf.sprintf "ref<%s>" (string_of_ty elem)
  | Ty_Defined { name; args } ->
      let base = name.name in
      if args = [] then base
      else
        Printf.sprintf "%s<%s>" base
          (String.concat ", " (List.map string_of_ty args))

let is_numeric_const_ty = function
  | Ty_Int8 | Ty_Int16 | Ty_Int32 | Ty_Int64 | Ty_UInt8 | Ty_UInt16 | Ty_UInt32
  | Ty_UInt64 | Ty_Float | Ty_Double ->
      true
  | Ty_Bool | Ty_Unit | Ty_StringLit | Ty_CharLit -> false

let is_integer_const_ty = function
  | Ty_Int8 | Ty_Int16 | Ty_Int32 | Ty_Int64 | Ty_UInt8 | Ty_UInt16 | Ty_UInt32
  | Ty_UInt64 ->
      true
  | Ty_Bool | Ty_Unit | Ty_Float | Ty_Double | Ty_StringLit | Ty_CharLit ->
      false

let normalized_builtin_ty_name (ty : ty) : string option =
  match ty.ty_desc with
  | Ty_Constant Ty_Int8 -> Some "int8"
  | Ty_Constant Ty_Int16 -> Some "int16"
  | Ty_Constant Ty_Int32 -> Some "int32"
  | Ty_Constant Ty_Int64 -> Some "int64"
  | Ty_Constant Ty_UInt8 -> Some "uint8"
  | Ty_Constant Ty_UInt16 -> Some "uint16"
  | Ty_Constant Ty_UInt32 -> Some "uint32"
  | Ty_Constant Ty_UInt64 -> Some "uint64"
  | Ty_Constant Ty_Bool -> Some "bool"
  | Ty_Constant Ty_Unit -> Some "unit"
  | Ty_Constant Ty_Float -> Some "float"
  | Ty_Constant Ty_Double -> Some "double"
  | Ty_Constant Ty_StringLit -> Some "str"
  | Ty_Constant Ty_CharLit -> Some "char"
  | Ty_Defined { name; args = [] } -> Some name.name
  | Ty_Var _ | Ty_Any | Ty_Arrow _ | Ty_Tuple _ | Ty_Array _ | Ty_Ref _
  | Ty_Defined _ ->
      None

let ensure_numeric_ty (t : ty) : unit =
  match t.ty_desc with
  | Ty_Constant c when not (is_numeric_const_ty c) ->
      raise
        (Type_error
           (Printf.sprintf "expected numeric type, got %s" (string_of_ty t)))
  | Ty_Var _ | Ty_Any | Ty_Constant _ -> ()
  | _ ->
      raise
        (Type_error
           (Printf.sprintf "expected numeric type, got %s" (string_of_ty t)))

let ensure_integer_ty (t : ty) : unit =
  match t.ty_desc with
  | Ty_Constant c when not (is_integer_const_ty c) ->
      raise
        (Type_error
           (Printf.sprintf "expected integer type, got %s" (string_of_ty t)))
  | Ty_Var _ | Ty_Any | Ty_Constant _ -> ()
  | _ ->
      raise
        (Type_error
           (Printf.sprintf "expected integer type, got %s" (string_of_ty t)))

let rec equal_ty (left : ty) (right : ty) : bool =
  match (left.ty_desc, right.ty_desc) with
  | Ty_Any, _ | _, Ty_Any -> true
  | Ty_Var a, Ty_Var b -> (
      match (a.variable, b.variable) with Some x, Some y -> x = y | _ -> false)
  | Ty_Constant a, Ty_Constant b -> a = b
  | Ty_Arrow (a_args, a_ret), Ty_Arrow (b_args, b_ret) ->
      List.length a_args = List.length b_args
      && List.for_all2 equal_ty a_args b_args
      && equal_ty a_ret b_ret
  | Ty_Tuple a_elems, Ty_Tuple b_elems ->
      List.length a_elems = List.length b_elems
      && List.for_all2 equal_ty a_elems b_elems
  | Ty_Array a_elem, Ty_Array b_elem -> equal_ty a_elem b_elem
  | Ty_Ref a_elem, Ty_Ref b_elem -> equal_ty a_elem b_elem
  | Ty_Defined a_def, Ty_Defined b_def ->
      String.equal a_def.name.name b_def.name.name
      && List.length a_def.args = List.length b_def.args
      && List.for_all2 equal_ty a_def.args b_def.args
  | _ -> (
      match
        (normalized_builtin_ty_name left, normalized_builtin_ty_name right)
      with
      | Some l, Some r -> String.equal l r
      | _ -> false)

let rec occurs (v : int) (t : ty) : bool =
  match t.ty_desc with
  | Ty_Var { variable = Some v'; _ } -> v = v'
  | Ty_Var { variable = None; _ } -> false
  | Ty_Arrow (args, ret) -> List.exists (occurs v) args || occurs v ret
  | Ty_Tuple elems -> List.exists (occurs v) elems
  | Ty_Array elem -> occurs v elem
  | Ty_Ref elem -> occurs v elem
  | Ty_Defined d -> List.exists (occurs v) d.args
  | Ty_Constant _ | Ty_Any -> false

let rec unify (s : Subst.t) (a : ty) (b : ty) : Subst.t =
  let a = Subst.apply s a in
  let b = Subst.apply s b in
  match (a.ty_desc, b.ty_desc) with
  | Ty_Any, _ | _, Ty_Any -> s
  | Ty_Var { variable = Some va; _ }, Ty_Var { variable = Some vb; _ }
    when va = vb ->
      s
  | _ when equal_ty a b -> s
  | Ty_Var { variable = Some v; _ }, _ ->
      if occurs v b then
        raise
          (Type_error
             (Printf.sprintf
                "occurs check failed: cannot bind '%d to %s while unifying %s \
                 and %s"
                v (string_of_ty b) (string_of_ty a) (string_of_ty b)))
      else Subst.bind v b s
  | _, Ty_Var { variable = Some v; _ } ->
      if occurs v a then
        raise
          (Type_error
             (Printf.sprintf
                "occurs check failed: cannot bind '%d to %s while unifying %s \
                 and %s"
                v (string_of_ty a) (string_of_ty a) (string_of_ty b)))
      else Subst.bind v a s
  | Ty_Constant ca, Ty_Constant cb when ca = cb -> s
  | Ty_Arrow (a1, r1), Ty_Arrow (a2, r2) ->
      if List.length a1 <> List.length a2 then
        raise
          (Type_error
             (Printf.sprintf
                "function arity mismatch: left has %d args, right has %d args \
                 (%s vs %s)"
                (List.length a1) (List.length a2) (string_of_ty a)
                (string_of_ty b)))
      else
        let s = List.fold_left2 (fun s x y -> unify s x y) s a1 a2 in
        unify s r1 r2
  | Ty_Tuple a1, Ty_Tuple a2 ->
      if List.length a1 <> List.length a2 then
        raise
          (Type_error
             (Printf.sprintf
                "tuple arity mismatch: left has %d elems, right has %d elems \
                 (%s vs %s)"
                (List.length a1) (List.length a2) (string_of_ty a)
                (string_of_ty b)))
      else List.fold_left2 (fun s x y -> unify s x y) s a1 a2
  | Ty_Array x, Ty_Array y -> unify s x y
  | Ty_Ref x, Ty_Ref y -> unify s x y
  | Ty_Defined da, Ty_Defined db
    when da.name.name = db.name.name
         && List.length da.args = List.length db.args ->
      List.fold_left2 (fun s x y -> unify s x y) s da.args db.args
  | Ty_Defined da, Ty_Defined db when da.name.name = db.name.name ->
      raise
        (Type_error
           (Printf.sprintf
              "type argument arity mismatch for %s: left has %d args, right \
               has %d args"
              da.name.name (List.length da.args) (List.length db.args)))
  | _ ->
      raise
        (Type_error
           (Printf.sprintf "type mismatch: %s vs %s" (string_of_ty a)
              (string_of_ty b)))

let apply_ty (ctx : Env.infer_ctx) (t : ty) : ty = Subst.apply ctx.subst t

let unify_into (ctx : Env.infer_ctx) (a : ty) (b : ty) : Env.infer_ctx =
  let s = unify ctx.subst a b in
  { ctx with subst = Subst.compose s ctx.subst }

let rec ty_vars (t : ty) : int list =
  match t.ty_desc with
  | Ty_Var { variable = Some v; _ } -> [ v ]
  | Ty_Var { variable = None; _ } -> []
  | Ty_Arrow (args, ret) -> List.concat_map ty_vars args @ ty_vars ret
  | Ty_Tuple elems -> List.concat_map ty_vars elems
  | Ty_Array elem -> ty_vars elem
  | Ty_Ref elem -> ty_vars elem
  | Ty_Defined d -> List.concat_map ty_vars d.args
  | Ty_Constant _ | Ty_Any -> []

let get_fn_args_ty (fn_ty : ty) : ty list * ty =
  match fn_ty.ty_desc with
  | Ty_Arrow (args, ret) -> (args, ret)
  | _ ->
      raise
        (Type_error
           (Printf.sprintf "expected function type, got %s" (string_of_ty fn_ty)))
