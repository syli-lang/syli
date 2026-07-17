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

String literal prints via syli_print_str:
  $ cat >test_str.sy <<EOF
  > signature:
  >   extern syli_print_str : str -> unit = "syli_print_str"
  > end
  > let s = "hello"
  > fn main () = syli_print_str s
  > EOF
  $ dune exec sylic -- build test_str.sy
  $ ./test_str.exe
  hello

Empty string literal compiles and runs:
  $ cat >test_empty.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > let s = ""
  > fn main () =
  >   syli_print_i64 42
  > EOF
  $ dune exec sylic -- build test_empty.sy
  $ ./test_empty.exe
  42

Empty string printed via syli_print_str:
  $ cat >test_empty2.sy <<EOF
  > signature:
  >   extern syli_print_str : str -> unit = "syli_print_str"
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > let s = ""
  > fn main () =
  >   syli_print_str s
  >   syli_print_i64 42
  > EOF
  $ dune exec sylic -- build test_empty2.sy
  $ ./test_empty2.exe
  42

Global int64 value read inside a function body:
  $ cat >test_global.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > let x = 42
  > fn main () = syli_print_i64 x
  > EOF
  $ dune exec sylic -- build test_global.sy
  $ ./test_global.exe
  42

Global str value read inside a function body:
  $ cat >test_global_str.sy <<EOF
  > signature:
  >   extern syli_print_str : str -> unit = "syli_print_str"
  > end
  > let s = "global str"
  > fn main () = syli_print_str s
  > EOF
  $ dune exec sylic -- build test_global_str.sy
  $ ./test_global_str.exe
  global str

String escape sequences:
  $ cat >test_esc_str.sy <<EOF
  > signature:
  >   extern syli_print_str : str -> unit = "syli_print_str"
  > end
  > fn main () =
  >   syli_print_str "hello\nworld"
  >   syli_print_str "\x41\x42\x43"
  >   syli_print_str "quot\"here"
  >   syli_print_str "back\\\\slash"
  > EOF
  $ dune exec sylic -- build test_esc_str.sy
  $ ./test_esc_str.exe
  hello
  worldABCquot"hereback\slash

Char literal printed via syli_print_char:
  $ cat >test_char.sy <<EOF
  > signature:
  >   extern syli_print_char : char -> unit = "syli_print_char"
  > end
  > fn main () = syli_print_char 'A'
  > EOF
  $ dune exec sylic -- build test_char.sy
  $ ./test_char.exe
  A
