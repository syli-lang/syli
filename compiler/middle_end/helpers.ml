open Syli_ir.Cir

let rec type_key_of_ty (t : ty) : string =
  match t.ir_type with
  | CR_Bool -> "bool"
  | CR_I64 -> "i64"
  | CR_I32 -> "i32"
  | CR_I16 -> "i16"
  | CR_I8 -> "i8"
  | CR_U64 -> "u64"
  | CR_U32 -> "u32"
  | CR_U16 -> "u16"
  | CR_U8 -> "u8"
  | CR_Float -> "f32"
  | CR_Double -> "f64"
  | CR_FnPtr -> "fn_ptr"
  | CR_Void -> "void"
  | CR_GenericTyp { type_var } -> "gen" ^ string_of_int type_var
  | CR_Ptr inner -> "ptr_" ^ type_key_of_ty inner
  | CR_Obj { named; args } ->
      let name = match named with Some n -> n | None -> "obj" in
      if args = [] then "obj_" ^ name
      else
        "obj_" ^ name ^ "_" ^ String.concat "_" (List.map type_key_of_ty args)
  | CR_Arrow (args, ret) ->
      "fn_"
      ^ String.concat "_" (List.map type_key_of_ty args)
      ^ "_" ^ type_key_of_ty ret

let rec ir_type_equal (a : ir_type) (b : ir_type) : bool =
  match (a, b) with
  | CR_Arrow (args1, ret1), CR_Arrow (args2, ret2) ->
      List.length args1 = List.length args2
      && List.for_all2 (fun a b -> ty_equal a b) args1 args2
      && ty_equal ret1 ret2
  | CR_Ptr a, CR_Ptr b -> ty_equal a b
  | CR_Obj a, CR_Obj b ->
      a.named = b.named
      && List.length a.args = List.length b.args
      && List.for_all2 (fun a b -> ty_equal a b) a.args b.args
  | _ -> a = b

and ty_equal (a : ty) (b : ty) : bool = ir_type_equal a.ir_type b.ir_type

let specialization_name (fn_name : qualified_name) (arg_tys : ty list)
    (ret_ty : ty) : string =
  let rec check_ty ty =
    match ty.ir_type with
    | CR_Arrow (args, ret) -> List.for_all check_ty args && check_ty ret
    | CR_GenericTyp _ -> false
    | ty -> true
  in
  if not (check_ty ret_ty && List.for_all check_ty arg_tys) then
    failwith "Generic param ty for monomorphize funciton"
  else
    let suffix = String.concat "__" (List.map type_key_of_ty arg_tys) in
    if suffix = "" then fn_name
    else fn_name ^ "__" ^ suffix ^ "_ret_" ^ type_key_of_ty ret_ty
