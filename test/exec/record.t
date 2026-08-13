Returning a record from a function:
  $ cat >test_file.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > type person = { name: int64; age: int64 }
  > let make_person () = { name = 10; age = 30 }
  > fn main () =
  >   let record = make_person ()
  >   syli_print_i64 (record.age)
  > EOF
  $ dune exec sylic -- build test_file.sy
  $ ./test_file.exe
  30

Returning a record through a function constructing it with its param:
  $ cat >test_file.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > type person = { name: int64; age: int64 }
  > let mk (name : int64) = { name = name; age = 30 }
  > fn main () =
  >   let record = mk 42
  >   syli_print_i64 (record.name)
  > EOF
  $ dune exec sylic -- build test_file.sy
  $ ./test_file.exe
  42
