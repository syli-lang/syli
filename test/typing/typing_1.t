Basic type checking and inference

Integer literals and operations:
  $ cat >test_int.src <<EOF
  > let x = 42
  > let y = x + 10
  > EOF
  $ dune exec sylic typing test_int.src
  Typed test_int.src successfully: module Test_int with 2 top-level typed items
  Type Environment:
  {
    x : int64
    y : int64
  }

Boolean literals and operations:
  $ cat >test_bool.src <<EOF
  > let p = true
  > let q = false
  > EOF
  $ dune exec sylic typing test_bool.src
  Typed test_bool.src successfully: module Test_bool with 2 top-level typed items
  Type Environment:
  {
    p : bool
    q : bool
  }

String literals:
  $ cat >test_string.src <<EOF
  > let s = "hello"
  > let t = "world"
  > EOF
  $ dune exec sylic typing test_string.src
  Typed test_string.src successfully: module Test_string with 2 top-level typed items
  Type Environment:
  {
    s : string
    t : string
  }

Arithmetic operations result in integers:
  $ cat >test_arith.src <<EOF
  > let a = 5 + 3
  > let b = 10 - 2
  > let c = 4 * 6
  > let d = 20 / 4
  > EOF
  $ dune exec sylic typing test_arith.src
  Typed test_arith.src successfully: module Test_arith with 4 top-level typed items
  Type Environment:
  {
    a : int64
    b : int64
    c : int64
    d : int64
  }

  $ cat >test_arith.src <<EOF
  > let a = 5.0 + 3.0
  > let b = 10. - 2.0
  > let c = 4. * 6.
  > let d = 20. / 4.
  > EOF
  $ dune exec sylic typing test_arith.src
  Typed test_arith.src successfully: module Test_arith with 4 top-level typed items
  Type Environment:
  {
    a : double
    b : double
    c : double
    d : double
  }

Comparison operations result in booleans:
  $ cat >test_cmp.src <<EOF
  > let eq = 5 == 5
  > let ne = 3 != 4
  > let lt = 2 < 5
  > let le = 5 <= 5
  > let gt = 10 > 3
  > let ge = 5 >= 5
  > EOF
  $ dune exec sylic typing test_cmp.src
  Typed test_cmp.src successfully: module Test_cmp with 6 top-level typed items
  Type Environment:
  {
    eq : bool
    ge : bool
    gt : bool
    le : bool
    lt : bool
    ne : bool
  }

Tuple types:
  $ cat >test_tuple.src <<EOF
  > let pair = (1, 2)
  > let triple = (true, 42, "test")
  > EOF
  $ dune exec sylic typing test_tuple.src
  Typed test_tuple.src successfully: module Test_tuple with 2 top-level typed items
  Type Environment:
  {
    pair : (int64, int64)
    triple : (bool, int64, string)
  }

Tuple types:
  $ cat >test_tuple.src <<EOF
  > let pair x y = (x, y)
  > let triple x y z = (x, y, z)
  > let pair_int = pair 1
  > let one_int = pair_int 42
  > let one_str = pair_int "hello"
  > EOF
  $ dune exec sylic typing test_tuple.src
  Typed test_tuple.src successfully: module Test_tuple with 5 top-level typed items
  Type Environment:
  {
    one_int : (int64, int64)
    one_str : (int64, string)
    pair : forall '57 '59. ('57, '59) -> ('57, '59)
    pair_int : forall '70. ('70) -> (int64, '70)
    triple : forall '62 '64 '66. ('62, '64, '66) -> ('62, '64, '66)
  }

Lambda expressions:
  $ cat >test_lambda.src <<EOF
  > let id = x -> x
  > let double = x -> x + x
  > EOF
  $ dune exec sylic typing test_lambda.src
  
  Parse error in test_lambda.src at line 1, column 11
  
    1 | let id = x -> x
                    ^^^^^
  
  Unexpected token: 'ARROW'
  
  [1]

Curried lambda expressions:
  $ cat >test_curried.src <<EOF
  > let add = x -> y -> x + y
  > EOF
  $ dune exec sylic typing test_curried.src
  
  Parse error in test_curried.src at line 1, column 12
  
    1 | let add = x -> y -> x + y
                     ^^^^^
  
  Unexpected token: 'ARROW'
  
  [1]


Multiple bindings:
  $ cat >test_multi.src <<EOF
  > let x = 1
  > let y = 2
  > let z = x + y
  > EOF
  $ dune exec sylic typing test_multi.src
  Typed test_multi.src successfully: module Test_multi with 3 top-level typed items
  Type Environment:
  {
    x : int64
    y : int64
    z : int64
  }

  $ cat >array_list.t <<EOF
  > let arr = [1, 2, 3, 4]
  > let lst = [true, false, true]
  > EOF
  $ dune exec sylic typing array_list.t
  Typed array_list.t successfully: module Array_list with 2 top-level typed items
  Type Environment:
  {
    arr : forall '25. '25
    lst : forall '27. '27
  }


Identity function and partial application:
  $ cat >test_id.src <<EOF
  > let id x = x
  > let id_int = id 42
  > let id_str = id "hello"
  > let id_float = id 3.14
  > EOF
  $ dune exec sylic typing test_id.src
  Typed test_id.src successfully: module Test_id with 4 top-level typed items
  Type Environment:
  {
    id : forall '35. ('35) -> '35
    id_float : double
    id_int : int64
    id_str : string
  }


Closures as an argument:
  $ cat >test_closure.src <<EOF
  > let apply_twice f x = f (f x)
  > let double_x x = x + x
  > let result = apply_twice double_x 10
  > EOF
  $ dune exec sylic typing test_closure.src
  Typed test_closure.src successfully: module Test_closure with 3 top-level typed items
  Type Environment:
  {
    apply_twice : forall '45. (('45) -> '45, '45) -> '45
    double_x : forall '47. ('47) -> '47
    result : int64
  }

main function test with FFI and record types:
  $ cat >test_e2e_print.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > type person = { name: int64; age: int64 }
  > let record0 = { name = 10; age = 30 }
  > fn main () =
  >     let record1 = { name = 10; age = 30 }
  >     syli_print_i64(record1.age)
  > EOF
  $ dune exec sylic typing test_e2e_print.sy
  Typed test_e2e_print.sy successfully: module Test_e2e_print with 4 top-level typed items
  Type Environment:
  {
    main : (unit) -> unit
    record0 : person
    syli_print_i64 : (int64) -> unit
  }

Polymorpic Closures as an argument:
  $ cat >test_closure.src <<EOF
  > let id x = x
  > let apply_twice f x = f (f x)
  > let result_1 = apply_twice id 10
  > let result_2 = apply_twice id "hello"
  > EOF
  $ dune exec sylic typing test_closure.src
  Typed test_closure.src successfully: module Test_closure with 4 top-level typed items
  Type Environment:
  {
    apply_twice : forall '55. (('55) -> '55, '55) -> '55
    id : forall '47. ('47) -> '47
    result_1 : int64
    result_2 : string
  }

To support higher rank like rank 2 here: we need to annotate f,
type a. like OCaml did or forall a. like Haskell.
It could be supported easily by the type system but for the runtime support, we 
need more work to do, extend closure_graph or adapt it.
  $ cat >test_closure.src <<EOF
  > let id x = x
  > let apply_both f = (f 10, f "hello")
  > let result = apply_both id
  > EOF
  $ dune exec sylic typing test_closure.src
  Fatal error: exception Syli_typing__Env.Type_error("type mismatch: int64 vs string")
  [2]


  $ cat >test_closure.src <<EOF
  > let id x = x
  > let apply_twice f x = f (f x)
  > let result = apply_twice id id
  > EOF
  $ dune exec sylic typing test_closure.src
  Typed test_closure.src successfully: module Test_closure with 3 top-level typed items
  Type Environment:
  {
    apply_twice : forall '45. (('45) -> '45, '45) -> '45
    id : forall '37. ('37) -> '37
    result : forall '49. ('49) -> '49
  }


