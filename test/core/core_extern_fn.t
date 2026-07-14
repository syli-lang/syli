  $ cat >test_extern_fn.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > fn main () = syli_print_i64(42)
  > EOF
  $ dune exec sylic -- core test_extern_fn.sy
  module Test_extern_fn
  let syliTest_extern_fn.main = fun () : unit ->
      syliTest_extern_fn.syli_print_i64(42 : i64) : unit
  
