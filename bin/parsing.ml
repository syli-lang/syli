let rec string_of_ty (ty : Syli_parsing.Ast.ty) : string =
  match ty.ty_desc with
  | Ty_Constant Ty_Int64 -> "int"
  | Ty_Constant Ty_Int32 -> "int32"
  | Ty_Constant Ty_Int16 -> "int16"
  | Ty_Constant Ty_Int8 -> "int8"
  | Ty_Constant Ty_UInt64 -> "uint64"
  | Ty_Constant Ty_UInt32 -> "uint32"
  | Ty_Constant Ty_UInt16 -> "uint16"
  | Ty_Constant Ty_UInt8 -> "uint8"
  | Ty_Constant Ty_Bool -> "bool"
  | Ty_Constant Ty_Unit -> "unit"
  | Ty_Constant Ty_Float -> "float"
  | Ty_Constant Ty_Double -> "double"
  | Ty_Constant Ty_StringLit -> "string"
  | Ty_Constant Ty_CharLit -> "char"
  | Ty_Any -> "_"
  | Ty_Var v -> "'" ^ v
  | Ty_Array t -> "array[" ^ string_of_ty t ^ "]"
  | Ty_Tuple ts -> "(" ^ String.concat ", " (List.map string_of_ty ts) ^ ")"
  | Ty_Arrow (params, ret) ->
      let parts = List.map string_of_ty (params @ [ ret ]) in
      String.concat " -> " parts
  | Ty_Defined { name; args } ->
      if args = [] then name.name
      else
        name.name ^ "[" ^ String.concat ", " (List.map string_of_ty args) ^ "]"

let string_of_signature_item (si : Syli_parsing.Ast.signature_item) : string =
  match si.signature_item_desc with
  | Sig_Value { name; params; value_ty; external_fn } -> (
      let ty_str =
        if params = [] then string_of_ty value_ty
        else
          string_of_ty { value_ty with ty_desc = Ty_Arrow (params, value_ty) }
      in
      match external_fn with
      | None -> "val " ^ name.name ^ " : " ^ ty_str
      | Some ext ->
          "extern " ^ name.name ^ " : " ^ ty_str ^ " = \"" ^ ext.c_name ^ "\"")
  | Sig_Type td -> "type " ^ td.name.name
  | Sig_Module ms -> "module " ^ ms.name.name

let string_of_structure_item (item : Syli_parsing.Ast.structure_item) : string =
  match item.structure_item_desc with
  | Str_Let ld ->
      Syli_parsing.Pretty_print_code.string_of_expr
        { id = item.id; expr_desc = Exp_Let ld; loc = item.loc }
  | Str_Fun { name; body; _ } ->
      "fn " ^ name.name ^ " = "
      ^ Syli_parsing.Pretty_print_ast.string_of_expr body
  | Str_TypeDef td -> "type " ^ td.name.name
  | Str_ModuleStruct m -> "module " ^ m.name.name
  | Str_Signature sigs ->
      "signature:\n"
      ^ String.concat "\n"
          (List.map (fun si -> "  " ^ string_of_signature_item si) sigs)
      ^ "\nend"

let run (filename : string) : unit =
  let ast = Syli_parsing.Utils.parse_file filename in
  Printf.printf "Parsed %s\n" filename;
  if ast.structure_items = [] then Printf.printf "(empty)\n"
  else
    List.iter
      (fun item -> Printf.printf "%s\n" (string_of_structure_item item))
      ast.structure_items
