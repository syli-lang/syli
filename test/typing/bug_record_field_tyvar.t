Record literal with a field bound to a type variable fails to infer:
  $ cat >test_field_var.src <<EOF
  > type person = { name: int64; age: int64 }
  > let mk name = { name = name; age = 30 }
  > EOF
  $ dune exec sylic typing test_field_var.src
  Fatal error: exception Syli_typing__Env.Type_error("cannot infer record type for fields {name, age}: no matching record type")
  [2]
