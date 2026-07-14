(** Post-lex pipeline:

    1) Collect raw located tokens with structural context.

    2) Apply indentation + whitespace filtering to produce parser tokens *)

open Syli_parser

type located_token = {
  tok : token;
  start_p : Lexing.position;
  end_p : Lexing.position;
}

type context = TopLevel | Inside
type contextual_token = located_token * context

let last_emitted_token : token option ref = ref None
let get_last_emitted_token () = !last_emitted_token

let is_open_construct = function
  | LBRACE | LBRACKET | LBRACKET_BAR -> true
  | _ -> false

let update_stack_on_token stack tok =
  match tok with
  | LBRACE | LBRACKET | LBRACKET_BAR -> Inside :: stack
  | RBRACE | RBRACKET | RBRACKET_BAR -> (
      match stack with _ :: tl -> tl | [] -> [ TopLevel ])
  | _ -> stack

let collect_with_context raw_token (lexbuf : Lexing.lexbuf) :
    contextual_token list =
  let rec loop stack acc =
    let tok = raw_token lexbuf in
    let lt = { tok; start_p = lexbuf.lex_start_p; end_p = lexbuf.lex_curr_p } in
    let ctx = match stack with TopLevel :: _ -> TopLevel | _ -> Inside in
    let next_stack = update_stack_on_token stack tok in
    let acc' = (lt, ctx) :: acc in
    if tok = EOF then List.rev acc' else loop next_stack acc'
  in
  loop [ TopLevel ] []

let layout (tokens : contextual_token list) : located_token list =
  let indent_stack = ref [ 0 ] in
  let pending_newline = ref false in
  let out = ref [] in
  let rec skip_top_spaces = function
    | ({ tok = SPACE _; _ }, TopLevel) :: tl -> skip_top_spaces tl
    | xs -> xs
  in
  let emit tok = out := tok :: !out in
  let emit_indent_change pos new_indent =
    let current = List.hd !indent_stack in
    if new_indent > current then (
      indent_stack := new_indent :: !indent_stack;
      emit { tok = INDENT; start_p = pos; end_p = pos })
    else
      while List.hd !indent_stack > new_indent do
        indent_stack := List.tl !indent_stack;
        emit { tok = DEDENT; start_p = pos; end_p = pos }
      done
  in
  let rec loop = function
    | [] -> ()
    | (lt, ctx) :: tl -> (
        match (lt.tok, ctx) with
        | (SPACE _ | NEWLINE), Inside -> loop tl
        | NEWLINE, TopLevel ->
            let lookahead = skip_top_spaces tl in
            (match lookahead with
            | ({ tok; _ }, TopLevel) :: _ when is_open_construct tok ->
                pending_newline := false
            | _ ->
                pending_newline := true;
                emit lt);
            loop tl
        | SPACE n, TopLevel when !pending_newline ->
            pending_newline := false;
            emit_indent_change lt.start_p n;
            loop tl
        | _, TopLevel when !pending_newline ->
            pending_newline := false;
            emit_indent_change lt.start_p 0;
            emit lt;
            loop tl
        | EOF, _ ->
            while List.length !indent_stack > 1 do
              indent_stack := List.tl !indent_stack;
              emit { tok = DEDENT; start_p = lt.start_p; end_p = lt.start_p }
            done;
            emit lt;
            loop tl
        | SPACE _, _ -> loop tl
        | _ ->
            pending_newline := false;
            emit lt;
            loop tl)
  in
  loop tokens;
  List.rev !out

let set_lexbuf_pos (lexbuf : Lexing.lexbuf) (ltok : located_token) =
  lexbuf.lex_start_p <- ltok.start_p;
  lexbuf.lex_curr_p <- ltok.end_p;
  last_emitted_token := Some ltok.tok;
  ltok.tok

let wrap_lexer raw_token =
  let stream : located_token list option ref = ref None in
  fun (lexbuf : Lexing.lexbuf) ->
    match !stream with
    | Some (next :: rest) ->
        stream := Some rest;
        set_lexbuf_pos lexbuf next
    | Some [] | None -> (
        let tokens = collect_with_context raw_token lexbuf |> layout in
        stream := Some tokens;
        match !stream with
        | Some (next :: rest) ->
            stream := Some rest;
            set_lexbuf_pos lexbuf next
        | _ -> EOF)
