let run (filename : string) : unit =
  let ast = Syli_parsing.Utils.parse_file filename in
  Printf.printf "Parsed %s\n" filename;
  if ast.structure_items = [] then Printf.printf "(empty)\n"
  else
    List.iter
      (fun item ->
        Printf.printf "%s\n"
          (Syli_parsing.Pretty_print_code.string_of_structure_item item))
      ast.structure_items
