let run (filename : string) : unit =
  let parsed = Syli_parsing.Utils.parse_file filename in
  let renamed = Syli_parsing.Alpha_renaming.run parsed.structure_items in
  renamed.prog
  |> List.map Syli_parsing.Pretty_print_code.string_of_structure_item
  |> String.concat "\n" |> print_endline
