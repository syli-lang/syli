type variant
  $ cat >test_variant.sy <<'EOF'
  > type option = None | Some of int64
  > EOF
  $ dune exec sylic parse test_variant.sy
  Parsed test_variant.sy
  type option = None | Some of int64

pattern match
  $ cat >test_pattern.sy <<'EOF'
  > let m =
  >   match x with
  >   | None -> 2
  >   | Some -> 3
  > EOF
  $ dune exec sylic parse test_pattern.sy
  Parsed test_pattern.sy
  let m = match x {
    | None -> 2
    | Some -> 3
  }

pattern match
  $ cat >test_pattern.sy <<'EOF'
  > let m =
  >   match x with None -> 2 | Some -> 3
  > EOF
  $ dune exec sylic parse test_pattern.sy
  Parsed test_pattern.sy
  let m = match x {
    | None -> 2
    | Some -> 3
  }


pattern match Any
  $ cat >test_pattern.sy <<'EOF'
  > let m = match x with None -> 2 | Some _ -> 3
  > EOF
  $ dune exec sylic parse test_pattern.sy
  Parsed test_pattern.sy
  let m = match x {
    | None -> 2
    | Some(_) -> 3
  }

variant constructors and pattern match
  $ cat >test_variant_match.sy <<'EOF'
  > type opt = None | Some of int64
  > type shape = Circle of { radius: double } | Rect of { w: double; h: double }
  > let w = Simple (Other (Some 3))
  > let r =
  >   match Circle { radius = 1.0 } with
  >   | Circle { radius = x } -> x
  > EOF
  $ dune exec sylic parse test_variant_match.sy
  Parsed test_variant_match.sy
  type opt = None | Some of int64
  type shape = Circle of { radius: double } | Rect of { w: double; h: double }
  let w = Simple(Other(Some(3)))
  let r = match Circle({ radius = 1.0 }) {
    | Circle({ radius = x }) -> x
  }

variant constructors and pattern match and when condition
  $ cat >test_variant_match.sy <<'EOF'
  > type opt = None | Some of int64
  > type shape = Circle of { radius: double } | Rect of { w: double; h: double }
  > let w = Simple (Other (Some 3))
  > let s = 0
  > let r =
  >   match Circle { radius = 1.0 } with
  >   | Circle { radius = x } when s == 0 -> x
  > EOF
  $ dune exec sylic parse test_variant_match.sy
  
  Parse error in test_variant_match.sy at line 7, column 26
  
    7 |   | Circle { radius = x } when s == 0 -> x
                                   ^^^^^^^^^^^
  
  Unexpected token: 'IDENT(when)'
  
  [1]
