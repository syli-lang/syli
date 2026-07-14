End-to-end runtime binary tests

Test 1: Compile, link, and run binary directly
  $ cat >test_binary.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > fn main () = syli_print_i64(42)
  > EOF
  $ dune exec sylic -- build test_binary.sy
  $ ./test_binary.exe && echo
  42

Test 3: Compile, link, and run another binary
  $ cat >startup_check.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > fn main () = syli_print_i64(1)
  > EOF
  $ dune exec sylic -- build startup_check.sy
  $ ./startup_check.exe && echo
  1

Closure as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > let apply f x y = f x y
  > let add x y z = x
  > fn main () =
  >   let add1 = add 1
  >   let result = apply add1 3 4
  >   let result2 = apply add1 1.0 2.0
  >   syli_print_i64 result
  > EOF
  $ dune exec sylic -- build test_multi.sy
  $ ./test_multi.exe
  1

Closure as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > let apply f x y = f x y
  > let add x y z = y
  > fn main () =
  >   let add1 = add 1
  >   let result =
  >     if false then
  >       apply add1 3 4
  >     else apply add1 7 2.0
  >   syli_print_i64 result
  > EOF
  $ dune exec sylic -- build test_multi.sy
  $ ./test_multi.exe
  7
