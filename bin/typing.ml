let run (filename : string) : unit =
  let parsed = Syli_parsing.Utils.parse_file filename in
  let infer_state, typed_ast = Syli_typing.Infer.infer_program parsed in
  Printf.printf
    "Typed %s successfully: module %s with %d top-level typed items\n" filename
    parsed.name.name
    (List.length typed_ast.structure_items);
  Syli_typing.Pp.print_env infer_state.env
