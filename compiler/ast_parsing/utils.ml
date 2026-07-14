open Syli_parser

let capitalize_module_name (name : string) : string =
  match String.length name with
  | 0 -> name
  | _ ->
      let first = Char.uppercase_ascii (String.get name 0) in
      Char.escaped first ^ String.sub name 1 (String.length name - 1)

let string_of_token = function
  | INT i -> Printf.sprintf "INT(%s)" i
  | IDENT s -> Printf.sprintf "IDENT(%s)" s
  | UIDENT s -> Printf.sprintf "UIDENT(%s)" s
  | FN -> "FN"
  | LET -> "LET"
  | RETURN -> "RETURN"
  | IF -> "IF"
  | ELSE -> "ELSE"
  | WHILE -> "WHILE"
  | MUT -> "MUT"
  | END -> "END"
  | LOCAL -> "LOCAL"
  | BOOL_VAL b -> Printf.sprintf "BOOL_VAL(%s)" b
  | LPAREN -> "LPAREN"
  | RPAREN -> "RPAREN"
  | LBRACKET -> "LBRACKET"
  | RBRACKET -> "RBRACKET"
  | LBRACKET_BAR -> "LBRACKET_BAR"
  | RBRACKET_BAR -> "RBRACKET_BAR"
  | LBRACE -> "LBRACE"
  | RBRACE -> "RBRACE"
  | COMMA -> "COMMA"
  | SEMI -> "SEMI"
  | NEWLINE -> "NEWLINE"
  | COLON -> "COLON"
  | EQ -> "EQ"
  | PLUS -> "PLUS"
  | MINUS -> "MINUS"
  | TIMES -> "TIMES"
  | DIV -> "DIV"
  | MOD -> "MOD"
  | LT -> "LT"
  | GT -> "GT"
  | EQEQ -> "EQEQ"
  | NEQ -> "NEQ"
  | LEQ -> "LEQ"
  | GEQ -> "GEQ"
  | LSHIFT -> "LSHIFT"
  | RSHIFT -> "RSHIFT"
  | AND -> "AND"
  | OR -> "OR"
  | NOT -> "NOT"
  | BITAND -> "BITAND"
  | BITOR -> "BITOR"
  | BITXOR -> "BITXOR"
  | BITNOT -> "BITNOT"
  | BREAK -> "BREAK"
  | CONTINUE -> "CONTINUE"
  | THEN -> "THEN"
  | ELSEIF -> "ELSEIF"
  | INDENT -> "INDENT"
  | DEDENT -> "DEDENT"
  | DOT -> "DOT"
  | ARROW -> "ARROW"
  | PLUS_EQ -> "PLUS_EQ"
  | MINUS_EQ -> "MINUS_EQ"
  | LAMBDA -> "LAMBDA"
  | MATCH -> "MATCH"
  | WITH -> "WITH"
  | UNDERSCORE -> "UNDERSCORE"
  | LOOP -> "LOOP"
  | DO -> "DO"
  | BANG -> "BANG"
  | STRING s -> Printf.sprintf "STRING(%s)" s
  | FLOAT f -> Printf.sprintf "FLOAT(%s)" f
  | CHAR c -> Printf.sprintf "CHAR(%s)" c
  | TY_UNIT -> "UNIT"
  | TY_BOOL -> "BOOL"
  | TY_INT -> "INT"
  | TY_FLOAT -> "FLOAT"
  | TY_CHAR -> "CHAR"
  | TY_STRING -> "STRING"
  | TY_ARRAY -> "ARRAY"
  | TY_LIST -> "LIST"
  | TY_TUPLE -> "TUPLE"
  | TY_INT8 -> "INT8"
  | TY_INT16 -> "INT16"
  | TY_INT32 -> "INT32"
  | TY_INT64 -> "INT64"
  | TY_UINT8 -> "UINT8"
  | TY_UINT16 -> "UINT16"
  | TY_UINT32 -> "UINT32"
  | TY_UINT64 -> "UINT64"
  | TY_DOUBLE -> "DOUBLE"
  | TYPE -> "TYPE"
  | MODULE -> "MODULE"
  | VAL -> "VAL"
  | PIPE -> "PIPE"
  | OF -> "OF"
  | SIGNATURE -> "SIGNATURE"
  | SPACE n -> Printf.sprintf "SPACE(%d)" n
  | EOF -> "EOF"
  | EXTERN -> "EXTERN"
  | REC -> "REC"

let parse_file filename =
  let ic = open_in filename in
  let lexbuf = Lexing.from_channel ic in
  let current_error_token () =
    let lexeme = Lexing.lexeme lexbuf in
    if lexeme <> "" then lexeme
    else
      match Syli_post_lex.get_last_emitted_token () with
      | Some tok -> string_of_token tok
      | None -> "<unknown>"
  in
  try
    let clean_token = Syli_post_lex.wrap_lexer Syli_lexer.token in
    let ast = Syli_parser.module_file_sy clean_token lexbuf in
    close_in ic;
    let ast =
      if ast.Ast.name.name = "" then
        let stem = Filename.basename filename |> Filename.remove_extension in
        {
          ast with
          Ast.name = { ast.Ast.name with name = capitalize_module_name stem };
        }
      else ast
    in
    ast
  with
  | Syli_lexer.Error msg ->
      close_in ic;
      Printf.eprintf "Lexer error: %s\n" msg;
      exit 1
  | Syli_parser.Error ->
      close_in ic;
      let pos = Lexing.lexeme_start_p lexbuf in
      let line = pos.Lexing.pos_lnum in
      let col = pos.Lexing.pos_cnum - pos.Lexing.pos_bol in
      let lexeme = current_error_token () in
      Error_reporting.show_error_context filename line col lexeme;
      exit 1
  | exn
    when String.equal (Printexc.to_string exn)
           "Parsing.Syli_parser.MenhirBasics.Error" ->
      close_in ic;
      let pos = Lexing.lexeme_start_p lexbuf in
      let line = pos.Lexing.pos_lnum in
      let col = pos.Lexing.pos_cnum - pos.Lexing.pos_bol in
      let lexeme = current_error_token () in
      Error_reporting.show_error_context filename line col lexeme;
      exit 1
  | exn ->
      close_in ic;
      Printf.eprintf "Unexpected error: %s\n" (Printexc.to_string exn);
      exit 1
