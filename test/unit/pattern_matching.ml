(** Unit tests for the core-AST pattern-matching decision-tree compiler.

    Each test is a real Syli program lowered through parsing, typing and the
    typed->core desugarer; the first [match] in the program is fed to
    [Pattern_matching.compile_match]. *)

module C = Syli_core.Core_ast
module PM = Middle_end.Pattern_matching
module Lower = Middle_end.Lower_ast_to_core

(* ------------------------------------------------------------------ *)
(* Decision-tree printer                                               *)
(* ------------------------------------------------------------------ *)

let pp_const = function
  | C.CConst_Unit -> "unit"
  | C.CConst_BoolLit s -> "bool " ^ s
  | C.CConst_IntLit s -> "int " ^ s
  | C.CConst_CharLit s -> "char " ^ s
  | C.CConst_StringLit s -> "str " ^ s
  | C.CConst_FloatLit s -> "float " ^ s

let rec pp_occ (o : PM.occurrence) =
  match o with
  | PM.Occ_Scrutinee _ -> "root"
  | PM.Occ_Field (o, idx) -> Printf.sprintf "%s.%d" (pp_occ o) idx
  | PM.Occ_Tuple (o, i) -> Printf.sprintf "%s.%d" (pp_occ o) i
  | PM.Occ_Payload o -> Printf.sprintf "%s.payload" (pp_occ o)

let pp_test = function
  | PM.Test_Constant c -> pp_const c
  | PM.Test_Constructor { tag } -> Printf.sprintf "tag(%d)" tag

let strip_lebind s = String.split_first ~sep:"_" s |> Option.get |> snd

let pp_binds binds =
  match binds with
  | [] -> ""
  | _ ->
      "["
      ^ String.concat ", "
          (List.map
             (fun ((id : C.ident), o) ->
               Printf.sprintf "%s=%s" (strip_lebind id.name) (pp_occ o))
             binds)
      ^ "]"

let rec pp_tree = function
  | PM.DFail -> "fail"
  | PM.DLeaf { binds; _ } -> "leaf" ^ pp_binds binds
  | PM.DGuard { binds; on_pass; on_fail; _ } ->
      Printf.sprintf "guard%s{%s | %s}" (pp_binds binds) (pp_tree on_pass)
        (pp_tree on_fail)
  | PM.DSwitch { scrutinee; cases; default } ->
      Printf.sprintf "switch %s { %s; _ -> %s }" (pp_occ scrutinee)
        (String.concat "; "
           (List.map
              (fun (t, tr) ->
                Printf.sprintf "%s -> %s" (pp_test t) (pp_tree tr))
              cases))
        (pp_tree default)

(* ------------------------------------------------------------------ *)
(* Harness                                                             *)
(* ------------------------------------------------------------------ *)

let lower_source src =
  let f = Filename.temp_file "pm_test" ".sy" in
  let oc = open_out f in
  output_string oc (String.trim src);
  close_out oc;
  let ast = Syli_parsing.Utils.parse_file f in
  let _, typed = Syli_typing.Infer.infer_program ast in
  Sys.remove f;
  Lower.lower typed

let first_match (core : C.module_core) =
  let rec over = function
    | [] -> failwith "no match found in test source"
    | (it : C.structure_item) :: rest -> (
        match it.structure_item_desc with
        | C.CStr_Let { value; _ } -> (
            match value.C.node with
            | C.CExp_Match { expr; cases } -> (expr, cases)
            | _ -> over rest)
        | _ -> over rest)
  in
  over core.structure_items

let failures = ref 0

let run label expected src =
  let core = lower_source src in
  let scrutinee, cases = first_match core in
  let got = pp_tree (PM.compile_match ~scrutinee ~cases) in
  if got = expected then Printf.printf "ok   %s\n  %s\n" label got
  else (
    incr failures;
    Printf.printf "FAIL %s\n  expected: %s\n  got:      %s\n" label expected got)

let () =
  run "literal with wildcard default" "switch root { int 0 -> leaf; _ -> leaf }"
    {|
let x = 5
let m = match x with 0 -> 1 | _ -> 2
|};

  run "several literals"
    "switch root { int 2 -> leaf; int 1 -> leaf; _ -> leaf }"
    {|
let x = 5
let m = match x with 1 -> 1 | 2 -> 2 | _ -> 0
|};

  run "variant construtors"
    "switch root { tag(1) -> leaf[v=root.payload]; tag(0) -> leaf; _ -> fail }"
    {|
type option = None | Some of i64
let x = Some 3
let m = match x with None -> 0 | Some v -> v
|};

  run "variant with wildcard default"
    "switch root { tag(1) -> leaf[v=root.payload]; _ -> leaf }"
    {|
type option = None | Some of i64
let x = Some 3
let m = match x with Some v -> v | _ -> 0
|};

  run "record (no test, one column per field)" "leaf[y=root.1, x=root.0]"
    {|
type person = { name: i64; age: i64 }
let p = { name = 1; age = 2 }
let m = match p with { name = x; age = y } -> x
|};

  run "variant with record payload"
    "switch root { tag(1) -> leaf[hh=root.payload.1, ww=root.payload.0]; \
     tag(0) -> leaf[r=root.payload.0]; _ -> fail }"
    {|
type radius_w = { radius: f64 }
type dims = { w: f64; h: f64 }
type shape = Circle of radius_w | Rect of dims
let s = Circle { radius = 1.0 }
let m =
  match s with
  | Circle { radius = r } -> r
  | Rect { w = ww; h = hh } -> ww
|};

  run "nested variant construtags"
    "switch root { tag(1) -> leaf; tag(0) -> switch root.payload { tag(0) -> \
     leaf; tag(1) -> leaf[y=root.payload.payload]; _ -> fail }; _ -> fail }"
    {|
type option = None | Some of i64
type wrapper = Wrap of option | Nil
let x = Some 3
let w = Wrap x
let m =
  match w with
  | Wrap (Some y) -> y
  | Wrap None -> 0
  | Nil -> 1
|};

  run "tuple (no test, one column per element)" "leaf[b=root.1, a=root.0]"
    {|
let t = (1, 2)
let m = match t with (a, b) -> a
|};

  run "guard falls through to a later literal row"
    "switch root { int 0 -> guard{leaf | leaf}; _ -> leaf }"
    {|
let x = 5
let m =
  match x with
  | 0 when true -> 1
  | 0 -> 2
  | _ -> 3
|};

  run "guard keeps bindings for condition and body"
    "switch root { tag(1) -> guard[y=root.payload]{leaf[y=root.payload] | \
     leaf}; _ -> leaf }"
    {|
type option = None | Some of i64
foreign f : i64 -> bool = "f"
let x = Some 3
let m =
  match x with
  | Some y when f y -> y
  | _ -> 0
|};

  run "guard failure retries the remaining construtag rows"
    "switch root { tag(0) -> leaf; tag(1) -> \
     guard[y=root.payload]{leaf[y=root.payload] | switch root.payload { int 1 \
     -> leaf; _ -> leaf[y=root.payload] }}; _ -> fail }"
    {|
type option = None | Some of i64
foreign f : i64 -> bool = "f"
let x = Some 3
let m =
  match x with
  | Some y when f y -> 0
  | Some 1 -> 1
  | Some y -> y
  | None -> 1
|};

  run "earlier irrefutable row shadows a later specific one"
    "switch root { tag(1) -> leaf[v=root.payload]; _ -> leaf }"
    {|
type option = None | Some of i64
let x = Some 3
let m =
  match x with
  | Some v -> 0
  | Some 0 -> 1
  | _ -> 2
|};

  run "literal inside a construtag payload"
    "switch root { tag(1) -> switch root.payload { int 0 -> leaf; _ -> \
     leaf[v=root.payload] }; _ -> leaf }"
    {|
type option = None | Some of i64
let x = Some 3
let m =
  match x with
  | Some 0 -> 1
  | Some v -> 0
  | _ -> 2
|};

  run "tuple over multiple columns"
    "switch root.0 { tag(1) -> switch root.0.payload { int 1 -> leaf; _ -> \
     switch root.1 { tag(1) -> switch root.1.payload { int 2 -> leaf; _ -> \
     leaf }; _ -> leaf } }; _ -> switch root.1 { tag(1) -> switch \
     root.1.payload { int 2 -> leaf; _ -> leaf }; _ -> leaf } }"
    {|
type option = None | Some of i64
let p = (Some 1, None)
let m =
  match p with
  | (Some 1, _) -> 0
  | (_, Some 2) -> 1
  | _ -> 2
|};

  run "record fields and literals across columns"
    "switch root.0 { int 0 -> leaf[y=root.1]; _ -> switch root.1 { int 1 -> \
     leaf[nm=root.0]; _ -> leaf } }"
    {|
type person = { name: i64; age: i64 }
let p = { name = 1; age = 2 }
let m =
  match p with
  | { name = 0; age = y } -> y
  | { name = nm; age = 1 } -> nm
  | _ -> 0
|};

  run "list zip across two columns"
    "switch root.0 { tag(1) -> switch root.1 { tag(1) -> \
     leaf[ry=root.1.payload.1, y=root.1.payload.0, rx=root.0.payload.1, \
     x=root.0.payload.0]; tag(0) -> leaf; _ -> fail }; tag(0) -> leaf; _ -> \
     switch root.1 { tag(0) -> leaf; _ -> fail } }"
    {|
type list = Nil | Cons of (i64, list)
let xs = Nil
let ys = Nil
let m =
  match (xs, ys) with
  | (Nil, _) -> ys
  | (_, Nil) -> xs
  | (Cons (x, rx), Cons (y, ry)) -> xs
|};

  run "unit match is irrefutable" "leaf"
    {|
let m =
  match () with
  | () -> 0
  | _ -> 1
|};

  run "unit-typed binder is kept"
    "switch root { tag(0) -> leaf[y=root.payload]; _ -> fail }"
    {|
type u = Mk of unit
let x = Mk ()
let m = match x with Mk y -> 0
|};

  run "unit columns dropped, third column tested"
    "switch root.2 { int 3 -> leaf; int 2 -> leaf; _ -> fail }"
    {|
let x = ()
let y = ()
let z = 5
let m =
  match (x, y, z) with
  | ((), (), 2) -> 0
  | ((), (), 3) -> 1
|};

  run "tuple construtor payload"
    "switch root { tag(0) -> leaf; tag(1) -> switch root.payload.0 { int 0 -> \
     leaf; _ -> leaf }; _ -> fail }"
    {|
type list = Nil | Cons of (i64, list)
let xs = Nil
let m =
  match xs with
  | Cons (0, _) -> 0
  | Cons (_, _) -> 1
  | Nil -> 2
|};

  if !failures = 0 then print_string "all pattern-matching tests passed\n"
  else Printf.printf "%d pattern-matching test(s) failed\n" !failures
