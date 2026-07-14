  $ cat >test_file.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > let rec factorial n =
  >   if n == 0 then
  >     1
  >   else
  >     n * factorial (n - 1)
  > fn main () = syli_print_i64 (factorial 5)
  > EOF
  $ dune exec sylic -- build test_file.sy
  $ ./test_file.exe
  120

  $ cat >test_file.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > type person = { name: int64; age: int64 }
  > fn main () =
  >     let record = { name = 10; age = 30 }
  >     syli_print_i64(record.age)
  >     syli_print_i64(record.name)
  > EOF
  $ dune exec sylic -- build test_file.sy
  $ ./test_file.exe && echo
  3010

  $ cat >test_file.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > let add x y = x + y
  > let sub x y = x - y
  > fn main () =
  >   let add1 = add 1
  >   let sub1 = sub 1
  >   let f = if false then add1 else sub1
  >   let result = f 2
  >   syli_print_i64 result
  > EOF
  $ dune exec sylic -- build test_file.sy
  $ ./test_file.exe
  -1

  $ cat >test_file.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > let id x = x
  > let apply_twice f x = f (f x)
  > fn main () =
  >   let result_1 = apply_twice id 10
  >   syli_print_i64 result_1
  > EOF
  $ dune exec sylic -- build test_file.sy
  $ ./test_file.exe
  10

  $ cat >test_multi.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  >   extern syli_print_f64 : double -> unit = "syli_print_f64"
  > end
  > let add x z = z
  > fn main () =
  >   let add1 = add 1
  >   let d = add1 1.0
  >   let i = add1 1
  >   syli_print_i64 i
  >   syli_print_f64 d
  >   i
  > EOF
  $ dune exec sylic -- build test_multi.sy
  $ ./test_multi.exe
  11.000000

  $ cat >test_multi.sy <<EOF
  > let add x y z = z
  > fn main () =
  >   let add1 = add 1
  >   let d = add1 1.0 2
  >   let i = add1 1 2
  >   i
  > EOF
  $ dune exec sylic -- build test_multi.sy
  $ ./test_multi.exe

Monomorphization issue.
  $ cat >test_file.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > let add x y z = y + z
  > let apply () =
  >   let add1 = add 1
  >   let add1and2 = add1 2
  >   let result = add1and2 3
  > fn main () = 
  >   let result = apply ()
  >   syli_print_i64 result
  > EOF
  $ dune exec sylic -- build test_file.sy
  $ ./test_file.exe
  5

  $ cat >test_file.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > let add x y z = x + y + z
  > let apply () =
  >   let add1 = add 1
  >   let add1and2 = add1 2
  >   let result = add1and2 3
  > fn main () = 
  >   let result = apply ()
  >   syli_print_i64 result
  > EOF
  $ dune exec sylic -- build test_file.sy
  $ ./test_file.exe
  6
