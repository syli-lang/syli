  $ cat >parse0.src <<EOF
  > type person = { name: string; age: int64 }
  > fn add () =
  >     let record =
  >     {
  >         name = "test";
  >         age = 5
  >     }
  >     2
  > end
  > EOF
  $ dune exec sylic typing parse0.src
  Typed parse0.src successfully: module Parse0 with 2 top-level typed items
  Type Environment:
  {
    add : (unit) -> int64
  }

  $ cat >parse0.src <<EOF
  > type person = { name: string; age: int64 }
  > fn add () =
  >     let record =
  >     {
  >         name = "test";
  >         age = 5
  >     }
  >     2
  > end
  > EOF
  $ dune exec sylic typing parse0.src
  Typed parse0.src successfully: module Parse0 with 2 top-level typed items
  Type Environment:
  {
    add : (unit) -> int64
  }

  $ cat >parse0.src <<EOF
  > type grown_person = { name: string; age: int64; grown: bool }
  > type person = { name: string; age: int64 }
  > fn add () =
  >     let record =
  >     {
  >         name = "test";
  >         age = 5 ;
  >         grown = true
  >     }
  >     let record2 = { name = "test2"; age = 10 }
  >     2
  > end
  > EOF
  $ dune exec sylic typing parse0.src
  Typed parse0.src successfully: module Parse0 with 3 top-level typed items
  Type Environment:
  {
    add : (unit) -> int64
  }

  $ cat >parse0.src <<EOF
  > type grown_person = { name: string; age: int64; grown: bool }
  > type person = { name: string; age: int64 }
  > fn add () =
  >     let record =
  >     {
  >         name = "test";
  >         age = 5 ;
  >         grown = true
  >     }
  >     let record2 = { name = "test2"; age = 10 }
  >     record2.something
  > end
  > EOF
  $ dune exec sylic typing parse0.src
  Fatal error: exception Syli_typing__Env.Type_error("type person has no field 'something'")
  [2]

  $ cat >parse0.src <<EOF
  > type grown_person = { name: string; age: int64; grown: bool }
  > type person = { name: string; age: int64 }
  > fn add () =
  >     let record =
  >     {
  >         name = "test";
  >         age = 5 ;
  >         grown = true
  >     }
  >     let record2 = { name = "test2"; age = 10.0 }
  >     record2.something
  > end
  > EOF
  $ dune exec sylic typing parse0.src
  Fatal error: exception Syli_typing__Env.Type_error("cannot infer record type for fields {name, age}: no matching record type")
  [2]
