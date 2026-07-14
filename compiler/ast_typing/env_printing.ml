open Typed_ast
open Env
open Syli_common

let rec string_of_ty (t : ty) : string =
  match t.ty_desc with
  | TTy_Constant TTy_Int64 -> "int64"
  | TTy_Constant TTy_Int32 -> "int32"
  | TTy_Constant TTy_Int16 -> "int16"
  | TTy_Constant TTy_Int8 -> "int8"
  | TTy_Constant TTy_UInt64 -> "uint64"
  | TTy_Constant TTy_UInt32 -> "uint32"
  | TTy_Constant TTy_UInt16 -> "uint16"
  | TTy_Constant TTy_UInt8 -> "uint8"
  | TTy_Constant TTy_Float -> "float"
  | TTy_Constant TTy_Double -> "double"
  | TTy_Constant TTy_Bool -> "bool"
  | TTy_Constant TTy_Unit -> "unit"
  | TTy_Constant TTy_StringLit -> "string"
  | TTy_Constant TTy_CharLit -> "char"
  | TTy_Var v -> "'" ^ string_of_int v
  | TTy_Arrow (args, ret) ->
      let args_str = String.concat ", " (List.map string_of_ty args) in
      Printf.sprintf "(%s) -> %s" args_str (string_of_ty ret)
  | TTy_Array t' -> Printf.sprintf "array[%s]" (string_of_ty t')
  | TTy_Tuple ts ->
      let ts_str = String.concat ", " (List.map string_of_ty ts) in
      Printf.sprintf "(%s)" ts_str
  | TTy_Defined { name; args } ->
      let full_name = name.name in
      if args = [] then full_name
      else
        let args_str = String.concat ", " (List.map string_of_ty args) in
        Printf.sprintf "%s<%s>" full_name args_str
  | TTy_Any -> "_"

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
  | TTydef_Alias ty -> "alias = " ^ string_of_ty ty
  | TTydef_Record fields ->
      let field_strs =
        List.map
          (fun (f : record_field_decl) ->
            Printf.sprintf "%s: %s" f.field_name.name (string_of_ty f.field_ty))
          fields
      in
      "record {\n  " ^ String.concat "\n  " field_strs ^ "\n}"
  | TTydef_Variant ctors ->
      let ctor_strs =
        List.map
          (fun c ->
            let arg_str =
              match c.arg with
              | None -> ""
              | Some ty -> " of " ^ string_of_ty ty
            in
            Printf.sprintf "%s%s" c.name.name arg_str)
          ctors
      in
      "variant {\n  " ^ String.concat "\n  " ctor_strs ^ "\n}"
  | TTydef_Abstract -> "abstract"

let string_of_record_env (record_env : ty_record_info list StringMap.t) : string
    =
  let entries =
    StringMap.bindings record_env
    |> List.map (fun (key, infos) ->
        let info_strs =
          List.map
            (fun info ->
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
