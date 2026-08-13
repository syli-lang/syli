Record literal with a field bound to a type variable fails to infer:
  $ cat >test_field_var.src <<EOF
  > type person = { name: int64; age: int64 }
  > let mk name = { name = name; age = 30 }
  > EOF
  $ dune exec sylic typing test_field_var.src
  Typed test_field_var.src successfully: module Test_field_var with 2 top-level typed items
  Type Environment:
  {
    mk : (int64) -> person
  }
