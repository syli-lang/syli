{
open Syli_parser  (* Import token definitions from syli_parser.mly *)
exception Error of string

let identation =
  try
    int_of_string (Sys.getenv "SYLI_INDENTATION")
  with Not_found | Failure _ -> 4

let hex_digit c =
  match c with
  | '0'..'9' -> Char.code c - 48
  | 'a'..'f' -> Char.code c - 97
  | 'A'..'F' -> Char.code c - 65
  | _ -> raise (Error "invalid hex digit")

}

rule token = parse
  (* --- Comments (skip silently including the newline) --- *)
  | "//" [^'\n']* '\n'
    {
      Lexing.new_line lexbuf;
      token lexbuf
    }  (* Skip comment and newline *)
  | "//" [^'\n']* eof
    { token lexbuf }  (* Skip comment at end of file (no newline) *)

  (* --- Spaces and tabs (emit SPACE token) --- *)
  | [' ' '\t']+ as s
      { SPACE (
          String.fold_left
            (fun acc c ->
              if c = ' ' then
                acc + 1
              else
                acc + identation) 0 s)
      }

  (* --- Newlines (always emit NEWLINE) --- *)
  | '\n'
    {
      Lexing.new_line lexbuf;
      NEWLINE
    }

  (* --- Keywords --- *)
  | "fn"        { FN }
  | "return"    { RETURN }
  | "if"        { IF }
  | "else"      { ELSE }
  | "while"     { WHILE }
  | "let"       { LET }
  | "mutable"   { MUTABLE }
  | "local"     { LOCAL }
  | "end"       { END }
  | "continue"  { CONTINUE }
  | "break"     { BREAK }
  | "not"       { NOT }
  | "then"      { THEN }
  | "elseif"    { ELSEIF }
  | "do"        { DO }
  | "match"     { MATCH }
  | "with"      { WITH }
  | "lambda"    { LAMBDA }
  | "type"      { TYPE }
  | "of"        { OF }
  | "module"    { MODULE }
  | "val"       { VAL }
  | "extern"    { EXTERN }
  | "signature" { SIGNATURE }
  | "rec"       { REC }
  | "ref"       { REF }
  | "when"      { WHEN }
  
  (* --- Types --- *)
  | "str"       { TY_STR }
  | "int"       { TY_INT }
  | "float"     { TY_FLOAT }
  | "char"      { TY_CHAR }
  | "unit"      { TY_UNIT }
  | "bool"      { TY_BOOL }
  | "array"     { TY_ARRAY }
  | "list"      { TY_LIST }
  | "tuple"     { TY_TUPLE }
  | "int64"     { TY_INT64 }
  | "int32"     { TY_INT32 }
  | "int16"     { TY_INT16 }
  | "int8"      { TY_INT8 }
  | "uint64"    { TY_UINT64 }
  | "uint32"    { TY_UINT32 }
  | "uint16"    { TY_UINT16 }
  | "uint8"     { TY_UINT8 }
  | "float"   { TY_FLOAT }
  | "double"    { TY_DOUBLE }

  (* --- Boolean literals --- *)
  | "true" as b   { BOOL_VAL b }
  | "false" as b  { BOOL_VAL b }

  (* --- Identifiers --- *)
  | ['A'-'Z']['a'-'z' 'A'-'Z' '0'-'9' '_']* as id   { UIDENT id }
  | ['a'-'z' '_']['a'-'z' 'A'-'Z' '0'-'9' '_']* as id { IDENT id }
  | "___" ['a'-'z' 'A'-'Z' '0'-'9' '_']*
    { raise (Error "Indentifiers starting with __ are reserved.") }

  (* --- Literals --- *)
  | ['0'-'9']+ as num              { INT num }
  | ['0'-'9']+ '.' ['0'-'9']* as f { FLOAT f }
  | ''' [^'''] ''' as c            { CHAR (String.get c 1 |> String.make 1) }
  | '"' { string (Buffer.create 64) lexbuf }

  (* --- Punctuation and operators --- *)
  | "("         { LPAREN }
  | ")"         { RPAREN }
  | ","         { COMMA }
  | ";"         { SEMI }
  | ":"         { COLON }
  | ":="        { COLON_EQ }
  | "="         { EQ }
  | "=="        { EQEQ }
  | "!="        { BANGEQ }
  | "<="        { LEQ }
  | ">="        { GEQ }
  | "<"         { LT }
  | ">"         { GT }
  | "+"         { PLUS }
  | "-"         { MINUS }
  | "*"         { STAR }
  | "/"         { SLASH }
  | "+="        { PLUS_EQ }
  | "-="        { MINUS_EQ }
  | "~"         { TILDE }
  | "&"         { AMPAND }
  | "|"         { BAR }
  | "|||"       { BAR_3TIMES }
  | "^"         { CARET }
  | "<<"        { LSHIFT }
  | ">>"        { RSHIFT }
  | "%"         { PERCENT }
  | "["         { LBRACKET }
  | "]"         { RBRACKET }
  | "[|"        { LBRACKET_BAR }
  | "|]"        { RBRACKET_BAR }
  | "{"         { LBRACE }
  | "}"         { RBRACE }
  | "."         { DOT }
  | "->"        { ARROW }
  | "!"         { BANG }
  | "_"         { UNDERSCORE }
  | "&&"        { AMPANDAND }
  | "||"        { BARBAR }
  | '\r'        { token lexbuf }  (* ignore carriage returns *)

  (* --- End of file --- *)
  | eof         { EOF }

  (* --- Error handling --- *)
  | _ as c { raise (Error (Printf.sprintf "Unexpected character: %c" c)) }

and string buf = parse
  | '"' { STRING (Buffer.contents buf) }
  | '\\' 'n'  { Buffer.add_char buf '\n'; string buf lexbuf }
  | '\\' 't'  { Buffer.add_char buf '\t'; string buf lexbuf }
  | '\\' 'r'  { Buffer.add_char buf '\r'; string buf lexbuf }
  | '\\' '0'  { Buffer.add_char buf '\000'; string buf lexbuf }
  | '\\' '\\' { Buffer.add_char buf '\\'; string buf lexbuf }
  | '\\' '\"' { Buffer.add_char buf '"'; string buf lexbuf }
  | '\\' 'x' (['0'-'9' 'a'-'f' 'A'-'F'] as h1) (['0'-'9' 'a'-'f' 'A'-'F'] as h2) {
      Buffer.add_char buf (Char.chr ((hex_digit h1) * 16 + hex_digit h2));
      string buf lexbuf }
  | [^'"' '\\']+ as s { Buffer.add_string buf s; string buf lexbuf }
  | eof { raise (Error "Unterminated string literal") }
  | _ { raise (Error "Invalid character in string literal") }
