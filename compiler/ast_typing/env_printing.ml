open Typed_ast
open Env
open Syli_common

let rec string_of_ty (t : ty) : string =
  match t.ty_desc with
  | Ty_Constant Ty_Int64 -> "int64"
  | Ty_Constant Ty_Int32 -> "int32"
  | Ty_Constant Ty_Int16 -> "int16"
  | Ty_Constant Ty_Int8 -> "int8"
  | Ty_Constant Ty_UInt64 -> "uint64"
  | Ty_Constant Ty_UInt32 -> "uint32"
  | Ty_Constant Ty_UInt16 -> "uint16"
  | Ty_Constant Ty_UInt8 -> "uint8"
  | Ty_Constant Ty_Float -> "float"
  | Ty_Constant Ty_Double -> "double"
  | Ty_Constant Ty_Bool -> "bool"
  | Ty_Constant Ty_Unit -> "unit"
  | Ty_Constant Ty_StringLit -> "str"
  | Ty_Constant Ty_CharLit -> "char"
  | Ty_Var { variable = Some v; _ } -> "'" ^ string_of_int v
  | Ty_Var { label; variable = None } -> "'" ^ label
  | Ty_Arrow (args, ret) ->
      let args_str = String.concat ", " (List.map string_of_ty args) in
      Printf.sprintf "(%s) -> %s" args_str (string_of_ty ret)
  | Ty_Array t' -> Printf.sprintf "array[%s]" (string_of_ty t')
  | Ty_Ref t' -> Printf.sprintf "ref<%s>" (string_of_ty t')
  | Ty_Tuple ts ->
      let ts_str = String.concat ", " (List.map string_of_ty ts) in
      Printf.sprintf "(%s)" ts_str
  | Ty_Defined { name; args } ->
      let full_name = name.name in
      if args = [] then full_name
      else
        let args_str = String.concat ", " (List.map string_of_ty args) in
        Printf.sprintf "%s<%s>" full_name args_str
  | Ty_Any -> "_"

let string_of_scheme (s : scheme) : string =
  match s.vars with
  | [] -> string_of_ty s.body
  | vs ->
      let vs_str =
        String.concat " " (List.map (fun v -> "'" ^ string_of_int v) vs)
      in
      Printf.sprintf "forall %s. %s" vs_str (string_of_ty s.body)

let string_of_env (env : TyEnv.t) : string =
  let bindings = TyEnv.bindings env in
  if bindings = [] then "{ empty }"
  else
    let entries =
      List.map
        (fun (name, scheme) ->
          Printf.sprintf "  %s : %s" name (string_of_scheme scheme))
        bindings
    in
    "{\n" ^ String.concat "\n" entries ^ "\n}"

let string_of_ty_decl_desc (desc : ty_decl_desc) : string =
  match desc with
  | Tydef_Alias ty -> "alias = " ^ string_of_ty ty
  | Tydef_Record fields ->
      let field_strs =
        List.map
          (fun (f : record_field_decl) ->
            Printf.sprintf "%s: %s" f.field_name.name (string_of_ty f.field_ty))
          fields
      in
      "record {\n  " ^ String.concat "\n  " field_strs ^ "\n}"
  | Tydef_Variant ctors ->
      let ctor_strs =
        List.map
          (fun c ->
            let arg_str =
              match c.arg with
              | None -> ""
              | Some (Constr_ty ty) -> " of " ^ string_of_ty ty
              | Some (Constr_record fields) ->
                  let field_strs =
                    List.map
                      (fun (f : record_field_decl) ->
                        Printf.sprintf "%s: %s" f.field_name.name
                          (string_of_ty f.field_ty))
                      fields
                  in
                  " of { " ^ String.concat ", " field_strs ^ " }"
            in
            Printf.sprintf "%s%s" c.name.name arg_str)
          ctors
      in
      "variant {\n  " ^ String.concat "\n  " ctor_strs ^ "\n}"
  | Tydef_Abstract -> "abstract"

let string_of_record_env (record_env : ty_record_info list StringMap.t) : string
    =
  let entries =
    StringMap.bindings record_env
    |> List.map (fun ((key, infos) : string * ty_record_info list) ->
        let info_strs =
          List.map
            (fun (info : ty_record_info) ->
              Printf.sprintf "    %s: %s" info.ty_decl.name.name
                (string_of_ty_decl_desc info.ty_decl.def))
            infos
        in
        Printf.sprintf "  %s:\n%s" key (String.concat "\n" info_strs))
  in
  "{\n" ^ String.concat "\n" entries ^ "\n}"

let print_env (env : TyEnv.t) : unit =
  print_endline "Type Environment:";
  print_endline (string_of_env env)
