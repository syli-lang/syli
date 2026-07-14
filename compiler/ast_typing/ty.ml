open Typed_ast
open Env

let mk_ty ty_desc = { ty_desc }

let string_of_const_ty = function
  | TTy_Int8 -> "int8"
  | TTy_Int16 -> "int16"
  | TTy_Int32 -> "int32"
  | TTy_Int64 -> "int64"
  | TTy_UInt8 -> "uint8"
  | TTy_UInt16 -> "uint16"
  | TTy_UInt32 -> "uint32"
  | TTy_UInt64 -> "uint64"
  | TTy_Bool -> "bool"
  | TTy_Unit -> "unit"
  | TTy_Float -> "float"
  | TTy_Double -> "double"
  | TTy_StringLit -> "string"
  | TTy_CharLit -> "char"

let rec string_of_ty (t : ty) : string =
  match t.ty_desc with
  | TTy_Var v -> Printf.sprintf "'%d" v
  | TTy_Any -> "_"
  | TTy_Constant c -> string_of_const_ty c
  | TTy_Arrow (args, ret) ->
      Printf.sprintf "(%s) -> %s"
        (String.concat ", " (List.map string_of_ty args))
        (string_of_ty ret)
  | TTy_Tuple elems ->
      Printf.sprintf "(%s)" (String.concat " * " (List.map string_of_ty elems))
  | TTy_Array elem -> Printf.sprintf "array<%s>" (string_of_ty elem)
  | TTy_Defined { name; args } ->
      let base = name.name in
      if args = [] then base
      else
        Printf.sprintf "%s<%s>" base
          (String.concat ", " (List.map string_of_ty args))

let is_numeric_const_ty = function
  | TTy_Int8 | TTy_Int16 | TTy_Int32 | TTy_Int64 | TTy_UInt8 | TTy_UInt16
  | TTy_UInt32 | TTy_UInt64 | TTy_Float | TTy_Double ->
      true
  | TTy_Bool | TTy_Unit | TTy_StringLit | TTy_CharLit -> false

let is_integer_const_ty = function
  | TTy_Int8 | TTy_Int16 | TTy_Int32 | TTy_Int64 | TTy_UInt8 | TTy_UInt16
  | TTy_UInt32 | TTy_UInt64 ->
      true
  | TTy_Bool | TTy_Unit | TTy_Float | TTy_Double | TTy_StringLit | TTy_CharLit
    ->
      false

let normalized_builtin_ty_name (ty : ty) : string option =
  match ty.ty_desc with
  | TTy_Constant TTy_Int8 -> Some "int8"
  | TTy_Constant TTy_Int16 -> Some "int16"
  | TTy_Constant TTy_Int32 -> Some "int32"
  | TTy_Constant TTy_Int64 -> Some "int64"
  | TTy_Constant TTy_UInt8 -> Some "uint8"
  | TTy_Constant TTy_UInt16 -> Some "uint16"
  | TTy_Constant TTy_UInt32 -> Some "uint32"
  | TTy_Constant TTy_UInt64 -> Some "uint64"
  | TTy_Constant TTy_Bool -> Some "bool"
  | TTy_Constant TTy_Unit -> Some "unit"
  | TTy_Constant TTy_Float -> Some "float"
  | TTy_Constant TTy_Double -> Some "double"
  | TTy_Constant TTy_StringLit -> Some "string"
  | TTy_Constant TTy_CharLit -> Some "char"
  | TTy_Defined { name; args = [] } -> Some name.name
  | TTy_Var _ | TTy_Any | TTy_Arrow _ | TTy_Tuple _ | TTy_Array _
  | TTy_Defined _ ->
      None

let ensure_numeric_ty (t : ty) : unit =
  match t.ty_desc with
  | TTy_Constant c when not (is_numeric_const_ty c) ->
      raise
        (Type_error
           (Printf.sprintf "expected numeric type, got %s" (string_of_ty t)))
  | TTy_Var _ | TTy_Any | TTy_Constant _ -> ()
  | _ ->
      raise
        (Type_error
           (Printf.sprintf "expected numeric type, got %s" (string_of_ty t)))

let ensure_integer_ty (t : ty) : unit =
  match t.ty_desc with
  | TTy_Constant c when not (is_integer_const_ty c) ->
      raise
        (Type_error
           (Printf.sprintf "expected integer type, got %s" (string_of_ty t)))
  | TTy_Var _ | TTy_Any | TTy_Constant _ -> ()
  | _ ->
      raise
        (Type_error
           (Printf.sprintf "expected integer type, got %s" (string_of_ty t)))

let rec equal_ty (left : ty) (right : ty) : bool =
  match (left.ty_desc, right.ty_desc) with
  | TTy_Any, _ | _, TTy_Any -> true
  | TTy_Var a, TTy_Var b -> a = b
  | TTy_Constant a, TTy_Constant b -> a = b
  | TTy_Arrow (a_args, a_ret), TTy_Arrow (b_args, b_ret) ->
      List.length a_args = List.length b_args
      && List.for_all2 equal_ty a_args b_args
      && equal_ty a_ret b_ret
  | TTy_Tuple a_elems, TTy_Tuple b_elems ->
      List.length a_elems = List.length b_elems
      && List.for_all2 equal_ty a_elems b_elems
  | TTy_Array a_elem, TTy_Array b_elem -> equal_ty a_elem b_elem
  | TTy_Defined a_def, TTy_Defined b_def ->
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
  | TTy_Var v' -> v = v'
  | TTy_Arrow (args, ret) -> List.exists (occurs v) args || occurs v ret
  | TTy_Tuple elems -> List.exists (occurs v) elems
  | TTy_Array elem -> occurs v elem
  | TTy_Defined d -> List.exists (occurs v) d.args
  | TTy_Constant _ | TTy_Any -> false

let rec unify (s : Subst.t) (a : ty) (b : ty) : Subst.t =
  let a = Subst.apply s a in
  let b = Subst.apply s b in
  match (a.ty_desc, b.ty_desc) with
  | TTy_Any, _ | _, TTy_Any -> s
  | TTy_Var va, TTy_Var vb when va = vb -> s
  | _ when equal_ty a b -> s
  | TTy_Var v, _ ->
      if occurs v b then
        raise
          (Type_error
             (Printf.sprintf
                "occurs check failed: cannot bind '%d to %s while unifying %s \
                 and %s"
                v (string_of_ty b) (string_of_ty a) (string_of_ty b)))
      else Subst.bind v b s
  | _, TTy_Var v ->
      if occurs v a then
        raise
          (Type_error
             (Printf.sprintf
                "occurs check failed: cannot bind '%d to %s while unifying %s \
                 and %s"
                v (string_of_ty a) (string_of_ty a) (string_of_ty b)))
      else Subst.bind v a s
  | TTy_Constant ca, TTy_Constant cb when ca = cb -> s
  | TTy_Arrow (a1, r1), TTy_Arrow (a2, r2) ->
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
  | TTy_Tuple a1, TTy_Tuple a2 ->
      if List.length a1 <> List.length a2 then
        raise
          (Type_error
             (Printf.sprintf
                "tuple arity mismatch: left has %d elems, right has %d elems \
                 (%s vs %s)"
                (List.length a1) (List.length a2) (string_of_ty a)
                (string_of_ty b)))
      else List.fold_left2 (fun s x y -> unify s x y) s a1 a2
  | TTy_Array x, TTy_Array y -> unify s x y
  | TTy_Defined da, TTy_Defined db
    when da.name.name = db.name.name
         && List.length da.args = List.length db.args ->
      List.fold_left2 (fun s x y -> unify s x y) s da.args db.args
  | TTy_Defined da, TTy_Defined db when da.name.name = db.name.name ->
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
  | TTy_Var v -> [ v ]
  | TTy_Arrow (args, ret) -> List.concat_map ty_vars args @ ty_vars ret
  | TTy_Tuple elems -> List.concat_map ty_vars elems
  | TTy_Array elem -> ty_vars elem
  | TTy_Defined d -> List.concat_map ty_vars d.args
  | TTy_Constant _ | TTy_Any -> []

let get_fn_args_ty (fn_ty : ty) : ty list * ty =
  match fn_ty.ty_desc with
  | TTy_Arrow (args, ret) -> (args, ret)
  | _ ->
      raise
        (Type_error
           (Printf.sprintf "expected function type, got %s" (string_of_ty fn_ty)))
