(* Enhanced error reporting for parsing errors *)

let escape_token lexeme =
  let buf = Buffer.create (String.length lexeme) in
  String.iter
    (function
      | '\n' -> Buffer.add_string buf "\\n"
      | '\r' -> Buffer.add_string buf "\\r"
      | '\t' -> Buffer.add_string buf "\\t"
      | '\\' -> Buffer.add_string buf "\\\\"
      | '\'' -> Buffer.add_string buf "\\'"
      | c -> Buffer.add_char buf c)
    lexeme;
  Buffer.contents buf

let get_line_content filename line_num =
  try
    let ic = open_in filename in
    let rec read_to_line n =
      if n = line_num then (
        let line = input_line ic in
        close_in ic;
        Some line)
      else if n < line_num then (
        ignore (input_line ic);
        read_to_line (n + 1))
      else (
        close_in ic;
        None)
    in
    read_to_line 1
  with End_of_file | Sys_error _ -> None

let show_error_context filename line col lexeme =
  Printf.eprintf "\n";
  Printf.eprintf "Parse error in %s at line %d, column %d\n" filename line col;
  Printf.eprintf "\n";
  (* Show the line with the error *)
  (match get_line_content filename line with
  | Some line_content ->
      Printf.eprintf "  %d | %s\n" line line_content;
      (* Show a caret pointing to the error location *)
      let spaces =
        String.make (col + String.length (string_of_int line) + 4) ' '
      in
      let carets = String.make (max 1 (String.length lexeme)) '^' in
      Printf.eprintf "  %s%s\n" spaces carets
  | None -> Printf.eprintf "  (unable to read source line)\n");
  Printf.eprintf "\n";
  Printf.eprintf "Unexpected token: '%s'\n" (escape_token lexeme);
  Printf.eprintf "\n"

let show_error_location (expr : Ast.expr) (msg : string) =
  let pos = expr.loc in
  Printf.eprintf "%s\n" msg;
  Printf.eprintf "Error at line %d, column %d\n" pos.start_pos pos.end_pos
