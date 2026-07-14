{
open Syli_parser  (* Import token definitions from syli_parser.mly *)
exception Error of string

let identation =
  try
    int_of_string (Sys.getenv "SYLI_INDENTATION")
  with Not_found | Failure _ -> 4

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
  | "mut"       { MUT }
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
  
  (* --- Types --- *)
  | "string"    { TY_STRING }
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
  | '"' [^'"']* '"' as s           { STRING (String.sub s 1 (String.length s - 2)) }

  (* --- Punctuation and operators --- *)
  | "("         { LPAREN }
  | ")"         { RPAREN }
  | ","         { COMMA }
  | ";"         { SEMI }
  | ":"         { COLON }
  | "="         { EQ }
  | "=="        { EQEQ }
  | "!="        { NEQ }
  | "<="        { LEQ }
  | ">="        { GEQ }
  | "<"         { LT }
  | ">"         { GT }
  | "+"         { PLUS }
  | "-"         { MINUS }
  | "*"         { TIMES }
  | "/"         { DIV }
  | "+="        { PLUS_EQ }
  | "-="        { MINUS_EQ }
  | "~"         { BITNOT }
  | "&"         { BITAND }
  | "|"         { BITOR }
  | "^"         { BITXOR }
  | "<<"        { LSHIFT }
  | ">>"        { RSHIFT }
  | "%"         { MOD }
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
  | "&&"        { AND }
  | "||"        { OR }
  | '\r'        { token lexbuf }  (* ignore carriage returns *)

  (* --- End of file --- *)
  | eof         { EOF }

  (* --- Error handling --- *)
  | _ as c { raise (Error (Printf.sprintf "Unexpected character: %c" c)) }
