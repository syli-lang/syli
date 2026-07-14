  $ cat >parse0.src <<EOF
  > type person = { name: string; age: int64 }
  > fn add x y = x + y
  > let add10 = add 10
  > let add20 = add10 20
  > EOF
  $ dune exec sylic typing parse0.src
  Typed parse0.src successfully: module Parse0 with 4 top-level typed items
  Type Environment:
  {
    add : forall '43. ('43, '43) -> '43
    add10 : (int64) -> int64
    add20 : int64
  }


  $ cat >parse0.src <<EOF
  > type person = { name: string; age: int64 }
  > fn add x y = x + y
  > let z = add 10 20
  > EOF
  $ dune exec sylic typing parse0.src
  Typed parse0.src successfully: module Parse0 with 3 top-level typed items
  Type Environment:
  {
    add : forall '37. ('37, '37) -> '37
    z : int64
  }


  $ cat >parse0.src <<EOF
  > type person = { name: string; age: int64 }
  > fn add x y = x + y
  > let z = add 10 20.
  > EOF
  $ dune exec sylic typing parse0.src
  Fatal error: exception Syli_typing__Env.Type_error("type mismatch: int64 vs double")
  [2]


  $ cat >parse0.src <<EOF
  > fn add x y = (x, y)
  > let add10 = add 10
  > let add20 = add10 20
  > EOF
  $ dune exec sylic typing parse0.src
  Typed parse0.src successfully: module Parse0 with 3 top-level typed items
  Type Environment:
  {
    add : forall '31 '33. ('31, '33) -> ('31, '33)
    add10 : forall '36. ('36) -> (int64, '36)
    add20 : (int64, int64)
  }

  $ cat >parse0.src <<EOF
  > fn add x y = (x, y)
  > let add10 = add 10
  > let add20 = add10 20
  > let add_float = add 10.0
  > EOF
  $ dune exec sylic typing parse0.src
  Typed parse0.src successfully: module Parse0 with 4 top-level typed items
  Type Environment:
  {
    add : forall '39 '41. ('39, '41) -> ('39, '41)
    add10 : forall '44. ('44) -> (int64, '44)
    add20 : (int64, int64)
    add_float : forall '49. ('49) -> (double, '49)
  }

Capturing partial application.
  $ cat >parse0.src <<EOF
  > fn add x y = (x, y)
  > let add10 = add 10
  > let add_fn () = add10
  > let add20 = add10 20
  > let add_float = add 10.0
  > let fn_r = add_fn ()
  > let fn_v = fn_r 20
  > EOF
  $ dune exec sylic typing parse0.src
  Typed parse0.src successfully: module Parse0 with 7 top-level typed items
  Type Environment:
  {
    add : forall '62 '64. ('62, '64) -> ('62, '64)
    add10 : forall '67. ('67) -> (int64, '67)
    add20 : (int64, int64)
    add_float : forall '75. ('75) -> (double, '75)
    add_fn : forall '70. (unit) -> ('70) -> (int64, '70)
    fn_r : forall '77. ('77) -> (int64, '77)
    fn_v : (int64, int64)
  }
