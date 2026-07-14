let run (filename : string) : unit =
  let ic = open_in filename in
  let lexbuf = Stdlib.Lexing.from_channel ic in
  try
    let clean_token =
      Syli_parsing.Syli_post_lex.wrap_lexer Syli_parsing.Syli_lexer.token
    in
    let rec print_tokens () =
      let token = clean_token lexbuf in
      Printf.printf "%s\n" (Syli_parsing.Utils.string_of_token token);
      if token <> Syli_parsing.Syli_parser.EOF then print_tokens ()
    in
    print_tokens ();
    close_in ic
  with
  | Syli_parsing.Syli_lexer.Error msg ->
      close_in_noerr ic;
      Printf.eprintf "Lexer error: %s\n" msg;
      exit 1
  | exn ->
      close_in_noerr ic;
      Printf.eprintf "Unexpected lexing error: %s\n" (Printexc.to_string exn);
      exit 1
