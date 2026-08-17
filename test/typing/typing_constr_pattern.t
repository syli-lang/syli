pattern match with variant constructors
  $ cat >test_pattern.sy <<'EOF'
  > type option = None | Some of int64
  > let opt = Some 3
  > let m =
  >   match opt with
  >   | None -> 2
  >   | Some _ -> 3
  > EOF
  $ dune exec sylic typing test_pattern.sy
  Typed test_pattern.sy successfully: module Test_pattern with 3 top-level typed items
  Type Environment:
  {
    m : int64
    opt : option
  }

constructor as a value
  $ cat >test_ctor_value.sy <<'EOF'
  > type option = None | Some of int64
  > let f = Some
  > let none = None
  > EOF
  $ dune exec sylic typing test_ctor_value.sy
  Typed test_ctor_value.sy successfully: module Test_ctor_value with 3 top-level typed items
  Type Environment:
  {
    f : (int64) -> option
    none : option
  }

nested variant constructors
  $ cat >test_nested.sy <<'EOF'
  > type opt = None | Some of int64
  > type wrapper = Simple of wrapper | Other of opt
  > let w = Simple (Other (Some 3))
  > EOF
  $ dune exec sylic typing test_nested.sy
  Typed test_nested.sy successfully: module Test_nested with 3 top-level typed items
  Type Environment:
  {
    w : wrapper
  }

nested constructors require parentheses
  $ cat >test_nested_reject.sy <<'EOF'
  > type opt = None | Some of int64
  > type wrapper = Simple of wrapper | Other of opt
  > let w = Simple Other Some 3
  > EOF
  $ dune exec sylic typing test_nested_reject.sy
  
  Parse error in test_nested_reject.sy at line 3, column 21
  
    3 | let w = Simple Other Some 3
                              ^^^^^^^^^^^^
  
  Unexpected token: 'UIDENT(Some)'
  
  [1]

  $ cat >test_nested_reject2.sy <<'EOF'
  > type opt = None | Some of int64
  > type wrapper = Simple of wrapper | Other of opt
  > let w = Simple Other (Some 3)
  > EOF
  $ dune exec sylic typing test_nested_reject2.sy
  
  Parse error in test_nested_reject2.sy at line 3, column 21
  
    3 | let w = Simple Other (Some 3)
                              ^
  
  Unexpected token: '('
  
  [1]

constructor with a record argument
  $ cat >test_constr_record.sy <<'EOF'
  > type shape = Circle of { radius: double } | Rect of { w: double; h: double }
  > let c = Circle { radius = 1.0 }
  > EOF
  $ dune exec sylic typing test_constr_record.sy
  Typed test_constr_record.sy successfully: module Test_constr_record with 2 top-level typed items
  Type Environment:
  {
    c : shape
  }

unknown variant constructor
  $ cat >test_unknown_ctor.sy <<'EOF'
  > let x = Foo 3
  > EOF
  $ dune exec sylic typing test_unknown_ctor.sy
  Fatal error: exception Syli_typing__Env.Type_error("unknown variant constructor 'Foo'")
  [2]

nullary constructor applied to an argument
  $ cat >test_nullary_ctor.sy <<'EOF'
  > type option = None | Some of int64
  > let x = None 3
  > EOF
  $ dune exec sylic typing test_nullary_ctor.sy
  Fatal error: exception Syli_typing__Env.Type_error("variant constructor 'None' takes no argument")
  [2]

constructor argument type mismatch
  $ cat >test_ctor_mismatch.sy <<'EOF'
  > type option = None | Some of int64
  > let x = Some "hi"
  > EOF
  $ dune exec sylic typing test_ctor_mismatch.sy
  Fatal error: exception Syli_typing__Env.Type_error("type mismatch: str vs int64")
  [2]

applying a constructed variant value
  $ cat >test_ctor_apply.sy <<'EOF'
  > type option = None | Some of int64
  > let x = (Some 3) 4
  > EOF
  $ dune exec sylic typing test_ctor_apply.sy
  Fatal error: exception Syli_typing__Env.Type_error("variant constructor 'Some' is not a function")
  [2]

variant constructors and pattern match and when condition
TODO: fix the type of 'x'
  $ cat >test_variant_match.sy <<'EOF'
  > type shape = Circle of { radius: double } | Rect of { w: double; h: double }
  > let s = 0
  > let r =
  >   match Circle { radius = 1.0 } with
  >   | Circle { radius = x } when s == 0 -> x
  > EOF
  $ dune exec sylic typing test_variant_match.sy
  Typed test_variant_match.sy successfully: module Test_variant_match with 3 top-level typed items
  Type Environment:
  {
    r : double
    s : int64
    x : '51
  }
