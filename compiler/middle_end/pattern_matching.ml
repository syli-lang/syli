(** Compile [Core_ast] pattern matches into a decision tree.

    This is an implementation of the classic pattern-matching compilation
    algorithm (Maranget's "Compiling Pattern Matching to Good Decision Trees"):
    a matrix of patterns is recursively refined into a tree of tests.

    Records and tuples are single-constructor, hence irrefutable: they are
    decomposed into one column per field and never emit a discriminating test.
    Only value literals and variant constructors are refutable and produce a
    [DSwitch].

    The chosen split column is brought to the front of every row before
    specialisation, so every [specialize_*] function only ever looks at column
    0.

    Constructors are identified by their numeric [tag] and record fields by
    their [field_idx]: core patterns carry these directly, so no names are
    needed and no resolution is deferred to lowering. *)

open Syli_core.Core_ast

exception Pattern_error of string

(** A location in the scrutinee value being matched, a structural path from the
    root. *)
type occurrence =
  | Occ_Scrutinee of expr
  | Occ_Field of occurrence * int  (** record field by [field_idx] *)
  | Occ_Tuple of occurrence * int  (** tuple element at index *)
  | Occ_Payload of occurrence  (** variant constructor argument *)

(** The discrimination performed by a [DSwitch]. *)
type pattern_test =
  | Test_Constant of constant
  | Test_Constructor of { tag : int }

type action_binds = (ident * occurrence) list
(** Binds a pattern variable to the occurrence it was matched against. *)

(** A decision tree.

    Binding scope:
    - [DLeaf.binds] are established before the body is evaluated.
    - [DGuard.binds] scope the [condition] and [on_pass]; since every leaf is
      self-contained (all decomposition-path bindings are flattened into it),
      [on_pass] repeats the guard bindings and needs no enclosing scope.
    - [on_fail] must *not* see [DGuard.binds]: bindings from a case whose guard
      failed are unwound before trying the remaining rows.

    [DFail] means no case matched; lowering should turn it into a match failure.*)
type decision_tree =
  | DFail
  | DLeaf of { binds : action_binds; body : expr }
  | DGuard of {
      binds : action_binds;
      condition : expr;
      on_pass : decision_tree;
      on_fail : decision_tree;
    }
  | DSwitch of {
      scrutinee : occurrence;
      cases : (pattern_test * decision_tree) list;
      default : decision_tree;
    }

(* Synthesised patterns never escape the compiler: leaves only bind original
   [Pat_Ident] patterns, so the id of a wildcard is never observed. *)
let wildcard_pat : pattern = { id = 0; node = Pat_Any }

(** Shape of a constructor argument. The type system already checked it. *)
type payload = Payload_None | Payload_One

(** The syntactic head of a pattern.

    [H_Default] is a wildcard or a binder; [H_Unit], [H_Tuple] and [H_Record]
    are irrefutable single-constructor heads; [H_Constant] and [H_Variant] are
    refutable. *)
type head =
  | H_Default
  | H_Constant of constant
  | H_Unit
  | H_Tuple of int
  | H_Record of pattern_record_field list
  | H_Variant of { tag : int; payload : payload }

module HeadSet = Set.Make (struct
  type t = head

  let compare h1 h2 = if h1 = h2 then 0 else 1
end)

let constant_of_literal = function
  | Pat_Unit -> Some CConst_Unit
  | Pat_BoolLit s -> Some (CConst_BoolLit s)
  | Pat_IntLit s -> Some (CConst_IntLit s)
  | Pat_CharLit s -> Some (CConst_CharLit s)
  | Pat_StringLit s -> Some (CConst_StringLit s)
  | Pat_FloatLit s -> Some (CConst_FloatLit s)
  | _ -> None

let head_of (p : pattern) : head =
  match p.node with
  | Pat_Any | Pat_Ident _ -> H_Default
  | Pat_Unit -> H_Unit
  | Pat_Tuple elements -> H_Tuple (List.length elements)
  | Pat_Record fields -> H_Record fields
  | Pat_Constructor { tag; pattern } ->
      H_Variant
        {
          tag;
          payload =
            (match pattern with None -> Payload_None | Some _ -> Payload_One);
        }
  | Pat_BoolLit _ | Pat_IntLit _ | Pat_CharLit _ | Pat_StringLit _
  | Pat_FloatLit _ -> (
      match constant_of_literal p.node with
      | Some c -> H_Constant c
      | None -> assert false)

let is_default_pattern (p : pattern) : bool =
  match p.node with Pat_Any | Pat_Ident _ -> true | _ -> false

(** If [p] is a binder, record it against the occurrence it matched.

    Every [Pat_Ident] is bound *)
let record_bind (p : pattern) (occ : occurrence) (binds : action_binds) :
    action_binds =
  match p.node with Pat_Ident id -> (id, occ) :: binds | _ -> binds

type row = {
  pats : pattern list;
  binds : action_binds;  (** bindings collected as columns are consumed *)
  guard : expr option;
  body : expr;
}
(** The matrix row *)

(** Drop column 0, recording a binder in it (if any) against the column's
    occurrence. *)
let strip_head (occs : occurrence list) (r : row) : row =
  match r.pats with
  | p :: rest ->
      let binds = record_bind p (List.hd occs) r.binds in
      { r with pats = rest; binds }
  | [] -> r

(** Replace column 0 by the patterns [subs] (used to expand a constructor or a
    single-constructor head). A binder in column 0 is recorded against the
    column's whole-value occurrence. *)
let expand_head (occs : occurrence list) (r : row) (subs : pattern list) : row =
  match r.pats with
  | p :: rest ->
      let binds = record_bind p (List.hd occs) r.binds in
      { r with pats = subs @ rest; binds }
  | [] -> r

(** Sub-pattern of [fields] with index [idx], if any. *)
let find_field (fields : pattern_record_field list) (idx : int) : pattern option
    =
  match
    List.find_opt (fun (x : pattern_record_field) -> x.field_idx = idx) fields
  with
  | Some { pattern; _ } -> pattern
  | None -> None

let subs_for_indices (indices : int list) (fields : pattern_record_field list) :
    pattern list =
  List.map
    (fun idx ->
      match find_field fields idx with Some p -> p | None -> wildcard_pat)
    indices

(** Specialise the matrix along a refutable constant. Rows headed by another
    constant are dropped *)
let specialize_constant (occs : occurrence list) (c : constant)
    (rows : row list) : row list =
  List.filter_map
    (fun r ->
      match r.pats with
      | p :: _ -> (
          match constant_of_literal p.node with
          | Some c' when c' = c -> Some (strip_head occs r)
          | Some _ -> None
          | None ->
              if is_default_pattern p then Some (strip_head occs r)
              else
                raise (Pattern_error "non-literal pattern in a literal column"))
      | [] -> None)
    rows

(** Specialise the matrix along a refutable variant constructor. Rows headed by
    another constructor are dropped. *)
let specialize_variant (occs : occurrence list) (occ : occurrence) (tag : int)
    (payload : payload) (rows : row list) : occurrence list * row list =
  let sub_occs =
    match payload with Payload_None -> [] | Payload_One -> [ Occ_Payload occ ]
  in
  let rows' =
    List.filter_map
      (fun r ->
        match r.pats with
        | p :: _ -> (
            match p.node with
            | Pat_Any | Pat_Ident _ ->
                let wilds = List.map (fun _ -> wildcard_pat) sub_occs in
                Some (expand_head occs r wilds)
            | Pat_Constructor { tag = t; pattern } when t = tag ->
                let subs =
                  match payload with
                  | Payload_None -> []
                  | Payload_One -> (
                      match pattern with
                      | Some sp -> [ sp ]
                      | None -> [ wildcard_pat ])
                in
                Some (expand_head occs r subs)
            | Pat_Constructor _ -> None
            | _ ->
                raise
                  (Pattern_error "non-constructor pattern in a variant column"))
        | [] -> None)
      rows
  in
  (sub_occs, rows')

(** Expand an irrefutable [unit] head (arity 0). *)
let specialize_unit (occs : occurrence list) (rows : row list) : row list =
  List.map
    (fun r ->
      match r.pats with
      | p :: _ -> (
          match p.node with
          | Pat_Unit | Pat_Any | Pat_Ident _ -> strip_head occs r
          | _ -> raise (Pattern_error "non-unit pattern in a unit column"))
      | [] -> r)
    rows

(** Expand an irrefutable tuple head, one column per element. *)
let specialize_tuple (occs : occurrence list) (occ : occurrence) (n : int)
    (rows : row list) : occurrence list * row list =
  let sub_occs = List.init n (fun i -> Occ_Tuple (occ, i)) in
  let rows' =
    List.map
      (fun r ->
        match r.pats with
        | p :: _ -> (
            match p.node with
            | Pat_Any | Pat_Ident _ ->
                expand_head occs r (List.init n (fun _ -> wildcard_pat))
            | Pat_Tuple elements -> expand_head occs r elements
            | _ -> raise (Pattern_error "non-tuple pattern in a tuple column"))
        | [] -> r)
      rows
  in
  (sub_occs, rows')

(** Expand an irrefutable record head, one column per field index in the matrix
    (ordered by sorted index). *)
let specialize_record (occs : occurrence list) (occ : occurrence)
    (rows : row list) : occurrence list * row list =
  let indices =
    List.filter_map
      (fun r ->
        match r.pats with
        | p :: _ -> (
            match p.node with
            | Pat_Record fields -> Some fields
            | Pat_Any | Pat_Ident _ -> None
            | _ -> raise (Pattern_error "non-record pattern in a record column")
            )
        | [] -> None)
      rows
    |> List.flatten
    |> List.map (fun p -> p.field_idx)
    |> List.sort_uniq Int.compare
  in
  let sub_occs = List.map (fun idx -> Occ_Field (occ, idx)) indices in
  let rows' =
    List.map
      (fun r ->
        match r.pats with
        | p :: _ -> (
            match p.node with
            | Pat_Any | Pat_Ident _ ->
                expand_head occs r (List.map (fun _ -> wildcard_pat) indices)
            | Pat_Record fields ->
                expand_head occs r (subs_for_indices indices fields)
            | _ -> raise (Pattern_error "non-record pattern in a record column")
            )
        | [] -> r)
      rows
  in
  (sub_occs, rows')

(** Number of distinct refutable heads in [col], over the whole matrix. *)
let refutable_head_count (col : int) (rows : row list) : int =
  List.fold_left
    (fun acc row ->
      match List.nth_opt row.pats col with
      | Some p -> (
          match head_of p with
          | (H_Constant _ | H_Variant _) as h -> HeadSet.add h acc
          | _ -> acc)
      | _ -> acc)
    HeadSet.empty rows
  |> HeadSet.cardinal

(** Heuristic f: favors columns i such that pattern p(1,i) is a generalized
    constructor pattern. In other words, the score function is [f(i) = 0] when
    [p (1,i) = _], and [f(i) = 1] otherwise. See the article for more details.

    [p(j,i)] : j row,i column

    TODO: there is more heuristics we could combine but for the first
    implementation, one is taken, and that is [f] *)
let choose_column (rows : row list) : int =
  match rows with
  | row :: _ -> (
      match
        List.find_index
          (fun (x : pattern) -> if is_default_pattern x then false else true)
          row.pats
      with
      | None -> assert false
      | Some x -> x)
  | _ -> assert false

(* ------------------------------------------------------------------ *)
(* Compilation                                                          *)
(* ------------------------------------------------------------------ *)

(** Split off the element at [col], returning it first and the remaining
    elements in their original relative order.*)
let pick_n (n : int) (l : 'a list) : 'a * 'a list =
  if n = 0 then (List.hd l, List.tl l)
  else
    let rec go i acc = function
      | [] -> raise (Pattern_error "column out of range")
      | x :: rest ->
          if i = n then (x, List.rev_append acc rest)
          else go (i + 1) (x :: acc) rest
    in
    go 0 [] l

(** Set column 0 of [r] to the pattern at [col], shifting the rest in order. *)
let reorder_head (col : int) (r : row) : row =
  let p, rest = pick_n col r.pats in
  { r with pats = p :: rest }

let swap_i (col : int) rows occs =
  let rows = if col = 0 then rows else List.map (reorder_head col) rows in
  (rows, pick_n col occs)

let rec compile (occs : occurrence list) (rows : row list) : decision_tree =
  match rows with
  | [] -> DFail (* 'default rows' and 'rest' rows could be empty*)
  | r :: rest -> (
      if List.for_all is_default_pattern r.pats then
        let bind_vars (pats : pattern list) (occs : occurrence list) :
            action_binds =
          List.combine pats occs
          |> List.fold_left (fun acc (p, o) -> record_bind p o acc) []
        in
        let binds = bind_vars r.pats occs @ r.binds in
        match r.guard with
        | None -> DLeaf { binds; body = r.body }
        | Some g ->
            DGuard
              {
                binds;
                condition = g;
                on_pass = DLeaf { binds; body = r.body };
                on_fail = compile occs rest;
              }
      else
        (* Choose and bring the split column to the front, then work on column 0. *)
        let col = choose_column rows in
        let rows, (occ, rest_occs) = swap_i col rows occs in
        let refutable_group =
          List.fold_left
            (fun acc row ->
              match row.pats with
              | p :: _ -> (
                  match head_of p with
                  | (H_Constant _ | H_Variant _) as h -> HeadSet.add h acc
                  | _ -> acc)
              | _ -> acc)
            HeadSet.empty rows
        in
        let test_of_head = function
          | H_Constant c -> Test_Constant c
          | H_Variant { tag; _ } -> Test_Constructor { tag }
          | _ -> assert false
        in
        if HeadSet.cardinal refutable_group > 0 then
          let cases =
            HeadSet.fold
              (fun h acc ->
                let sub_occs, rows' =
                  match h with
                  | H_Constant c -> ([], specialize_constant occs c rows)
                  | H_Variant { tag; payload } ->
                      specialize_variant occs occ tag payload rows
                  | _ -> assert false
                in
                (test_of_head h, compile (sub_occs @ rest_occs) rows') :: acc)
              refutable_group []
          in
          let default_rows (rows : row list) : row list =
            List.filter
              (fun r ->
                match r.pats with p :: _ -> head_of p = H_Default | _ -> false)
              rows
          in
          let dflt = default_rows rows in
          let default = compile rest_occs (List.map (strip_head occs) dflt) in
          DSwitch { scrutinee = occ; cases; default }
        else
          let first = List.hd rows in
          match first.pats with
          | p :: _ -> (
              match head_of p with
              | H_Unit -> compile rest_occs (specialize_unit occs rows)
              | H_Tuple n ->
                  let sub_occs, rows' = specialize_tuple occs occ n rows in
                  compile (sub_occs @ rest_occs) rows'
              | H_Record _ ->
                  let sub_occs, rows' = specialize_record occs occ rows in
                  compile (sub_occs @ rest_occs) rows'
              | _ -> raise (Pattern_error "unreachable irrefutable split"))
          | [] -> raise (Pattern_error "unreachable empty row"))

(* ------------------------------------------------------------------ *)
(* Entry points                                                       *)
(* ------------------------------------------------------------------ *)

let compile_match ~(scrutinee : expr) ~(cases : pattern_case list) :
    decision_tree =
  let occs = [ Occ_Scrutinee scrutinee ] in
  let rows =
    List.map
      (fun (pat_case : pattern_case) ->
        {
          pats = [ pat_case.pattern ];
          binds = [];
          guard = pat_case.when_condition;
          body = pat_case.body;
        })
      cases
  in
  compile occs rows
