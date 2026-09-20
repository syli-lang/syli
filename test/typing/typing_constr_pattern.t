pattern match with variant constructors
  $ cat >test_pattern.sy <<'EOF'
  > type option = None | Some of i64
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
    m : i64
    opt : option
  }

  $ cat >test_pattern.sy <<'EOF'
  > type option = None | Some of i64
  > let opt = Some 3
  > let m =
  >   match opt with
  >   | Some 1 -> 0
  >   | None -> 2
  > EOF
  $ dune exec sylic typing test_pattern.sy
  Typed test_pattern.sy successfully: module Test_pattern with 3 top-level typed items
  Type Environment:
  {
    m : i64
    opt : option
  }

constructor as a value
TODO: we must forbid this 'let f = Some' when 'Some' is defined with a argument.
  $ cat >test_ctor_value.sy <<'EOF'
  > type option = None | Some of i64
  > let f = Some
  > let none = None
  > EOF
  $ dune exec sylic typing test_ctor_value.sy
  Typed test_ctor_value.sy successfully: module Test_ctor_value with 3 top-level typed items
  Type Environment:
  {
    f : i64 -> option
    none : option
  }

nested variant constructors
  $ cat >test_nested.sy <<'EOF'
  > type opt = None | Some of i64
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
  > type opt = None | Some of i64
  > type wrapper = Simple of wrapper | Other of opt
  > let w = Simple Other Some 3
  > EOF
  $ dune exec sylic typing test_nested_reject.sy
  Typed test_nested_reject.sy successfully: module Test_nested_reject with 3 top-level typed items
  Type Environment:
  {
    w : wrapper
  }

  $ cat >test_nested_reject2.sy <<'EOF'
  > type opt = None | Some of i64
  > type wrapper = Simple of wrapper | Other of opt
  > let w = Simple Other (Some 3)
  > EOF
  $ dune exec sylic typing test_nested_reject2.sy
  Typed test_nested_reject2.sy successfully: module Test_nested_reject2 with 3 top-level typed items
  Type Environment:
  {
    w : wrapper
  }

constructor with a record argument
  $ cat >test_constr_record.sy <<'EOF'
  > type shape = Circle of { radius: f64 } | Rect of { w: f64; h: f64 }
  > let c = Circle { radius = 1.0 }
  > EOF
  $ dune exec sylic typing test_constr_record.sy
  Typed test_constr_record.sy successfully: module Test_constr_record with 2 top-level typed items
  Type Environment:
  {
    c : shape
  }

constructor with a record argument
  $ cat >test_constr_record.sy <<'EOF'
  > type shape = Circle of { radius: f64 } | Rect of { w: f64; h: f64 }
  > let c = Circle { radius = 1.0 }
  > let _ =
  >   match c with
  >   | Circle x -> x
  > EOF
  $ dune exec sylic typing test_constr_record.sy
  Type error in test_constr_record.sy at line 5, column 4
  
    5 |   | Circle x -> x
            ^^^^^^
  
  variant constructor 'Circle' expects a record pattern
  [1]

constructor with a record argument
  $ cat >test_constr_record.sy <<'EOF'
  > type radius = { radius: i64 }
  > type shape = Circle of radius | Rect of { w: f64; h: f64 }
  > let c = Circle { radius = 1 }
  > let r =
  >   match c with
  >   | Circle x -> x
  >   | Circle x -> x
  > EOF
  $ dune exec sylic typing test_constr_record.sy
  Typed test_constr_record.sy successfully: module Test_constr_record with 4 top-level typed items
  Type Environment:
  {
    c : shape
    r : radius
  }

unknown variant constructor
  $ cat >test_unknown_ctor.sy <<'EOF'
  > let x = Foo 3
  > EOF
  $ dune exec sylic typing test_unknown_ctor.sy
  Type error in test_unknown_ctor.sy at line 1, column 8
  
    1 | let x = Foo 3
                ^^^
  
  unknown variant constructor 'Foo'
  [1]

nullary constructor applied to an argument
  $ cat >test_nullary_ctor.sy <<'EOF'
  > type option = None | Some of i64
  > let x = None 3
  > EOF
  $ dune exec sylic typing test_nullary_ctor.sy
  Type error in test_nullary_ctor.sy at line 2, column 8
  
    2 | let x = None 3
                ^^^^
  
  variant constructor 'None' takes no argument
  [1]

constructor argument type mismatch
  $ cat >test_ctor_mismatch.sy <<'EOF'
  > type option = None | Some of i64
  > let x = Some "hi"
  > EOF
  $ dune exec sylic typing test_ctor_mismatch.sy
  Type error in test_ctor_mismatch.sy at line 2, column 16
  
    2 | let x = Some "hi"
                        ^
  
  type mismatch: string vs i64
  [1]

applying a constructed variant value
  $ cat >test_ctor_apply.sy <<'EOF'
  > type option = None | Some of i64
  > let x = (Some 3) 4
  > EOF
  $ dune exec sylic typing test_ctor_apply.sy
  Type error in test_ctor_apply.sy at line 2, column 9
  
    2 | let x = (Some 3) 4
                 ^^^^
  
  variant constructor 'Some' is not a function
  [1]

Composed pattern-match cases
  $ cat > test_composed.sy <<'EOF'
  > type option = None | Some of i64
  > type wrapper = Wrap of option | Nil
  > let x = Some 3
  > let z = None
  > let w = Wrap x
  > let m =
  >   match w with
  >   | Wrap (Some y) -> y
  >   | Wrap None -> 0
  >   | Nil -> 1
  > EOF
  $ dune exec sylic typing test_composed.sy
  Typed test_composed.sy successfully: module Test_composed with 6 top-level typed items
  Type Environment:
  {
    m : i64
    w : wrapper
    x : option
    z : option
  }

Composed pattern-match cases
  $ cat > test_composed.sy <<'EOF'
  > type option = None | Some of i64
  > type wrapper = Wrap of option | Nil
  > let x = Some 3
  > let z = None
  > let w = Wrap x
  > let m =
  >   match w with
  >   | Wrap (Some y) -> 2.0
  >   | Wrap None -> 0
  >   | Nil -> 1
  > EOF
  $ dune exec sylic typing test_composed.sy
  Type error in test_composed.sy at line 9, column 17
  
    9 |   | Wrap None -> 0
                         ^
  
  type mismatch: i64 vs f64
  [1]

List Constructor
  $  cat > test_list.sy <<'EOF'
  > type list = Nil | Cons of (i64, list)
  > let x = Cons (2, Nil)
  > let z =
  >   match x with
  >   | Cons y -> y
  > EOF
  $ dune exec sylic typing test_list.sy
  Typed test_list.sy successfully: module Test_list with 3 top-level typed items
  Type Environment:
  {
    x : list
    z : (i64 * list)
  }
