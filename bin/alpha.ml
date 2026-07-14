let string_of_structure_item (s : Syli_parsing.Ast.structure_item) : string =
  match s.structure_item_desc with
  | Syli_parsing.Ast.Str_Let ld ->
      let e : Syli_parsing.Ast.expr =
        { id = s.id; expr_desc = Exp_Let ld; loc = s.loc }
      in
      Syli_parsing.Pretty_print_code.string_of_expr e
  | Syli_parsing.Ast.Str_Fun { name; body; _ } ->
      Printf.sprintf "fn %s %s" name.name
        (Syli_parsing.Pretty_print_code.string_of_expr body)
  | Syli_parsing.Ast.Str_TypeDef td -> "type " ^ td.name.name
  | Syli_parsing.Ast.Str_ModuleStruct m -> "module " ^ m.name.name
  | Syli_parsing.Ast.Str_Signature _ -> "signature"

let run (filename : string) : unit =
  let parsed = Syli_parsing.Utils.parse_file filename in
  let renamed = Syli_parsing.Alpha_renaming.run parsed.structure_items in
  renamed.prog
  |> List.map string_of_structure_item
  |> String.concat "\n" |> print_endline
