Core AST pretty printing

Integer and boolean literals:
  $ cat >test_core_basic.sy <<EOF
  > let x = 42
  > let y = x + 10
  > let b = true
  > EOF
  $ dune exec sylic core test_core_basic.sy
  module Test_core_basic
  let syliTest_core_basic.x = 42 : i64
  
  let syliTest_core_basic.y = (syliTest_core_basic.x : i64 + 10 : i64) : i64
  
  let syliTest_core_basic.b = true : bool
  
If expression:
  $ cat >test_core_if.sy <<EOF
  > let x = 10
  > let y = if x > 5 then 1 else 0
  > EOF
  $ dune exec sylic core test_core_if.sy
  module Test_core_if
  let syliTest_core_if.x = 10 : i64
  
  let syliTest_core_if.y = if (syliTest_core_if.x : i64 > 5 : i64) : bool
      1 : i64
    else
      0 : i64
  

Use of external function and record creation:
  $ cat >test_e2e_print.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > type person = { name: int64; age: int64 }
  > fn main () =
  >     let record = { name = 10; age = 30 }
  >     syli_print_i64(record.age)
  > EOF
  $ dune exec sylic -- core test_e2e_print.sy
  module Test_e2e_print
  type person = { 0 : i64; 1 : i64 }
  
  let syliTest_e2e_print.main = fun () : unit ->
      {
        let syliTest_e2e_print.main__record = { 0 = 10 : i64; 1 = 30 : i64 } : person
        syliTest_e2e_print.syli_print_i64(syliTest_e2e_print.main__record.1 : i64) : unit
      }
  


Closures as an argument:
  $ cat >test_closure.src <<EOF
  > let apply_twice f x = f (f x)
  > let double_x x = x + x
  > let result = apply_twice double_x 10
  > EOF
  $ dune exec sylic -- core test_closure.src
  module Test_closure
  let syliTest_closure.apply_twice = fun (f, x) : 'a45 ->
      f(f(x : 'a45) : 'a45) : 'a45
  
  let syliTest_closure.double_x = fun (x) : 'a47 ->
      (x : 'a47 + x : 'a47) : 'a47
  
  let syliTest_closure.result = syliTest_closure.apply_twice(syliTest_closure.double_x : (i64) -> i64, 10 : i64) : i64
  

Closure with multipble chains of captured variables:
  $ cat >test_multi.sy <<EOF
  > let add x y z = x + y + z
  > let apply () =
  >   let add1 = add 1
  >   let add1and2 = add1 2
  >   let result = add1and2 3
  > EOF
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  let syliTest_multi.add = fun (x, y, z) : 'a55 ->
      ((x : 'a55 + y : 'a55) : 'a55 + z : 'a55) : 'a55
  
  let syliTest_multi.apply = fun () : i64 ->
      {
        let syliTest_multi.apply__add1 = syliTest_multi.add(1 : i64) : (i64, i64) -> i64
        let syliTest_multi.apply__add1and2 = syliTest_multi.apply__add1(2 : i64) : (i64) -> i64
        let syliTest_multi.apply__result = syliTest_multi.apply__add1and2(3 : i64) : i64
      }
  


Overriding same name variable in the top-level scope:
  $ cat >test_shadow.sy <<EOF
  > let x = 5
  > let y = x + 1
  > let x = 10
  > let result = x + 1
  > EOF
  $ dune exec sylic -- core test_shadow.sy
  module Test_shadow
  let syliTest_shadow.x#1 = 5 : i64
  
  let syliTest_shadow.y = (syliTest_shadow.x#1 : i64 + 1 : i64) : i64
  
  let syliTest_shadow.x = 10 : i64
  
  let syliTest_shadow.result = (syliTest_shadow.x : i64 + 1 : i64) : i64
  

Overriding same name variable in a nested scope:
  $ cat >test_shadow_nested.sy <<EOF
  > let x = 5
  > let apply () =
  >   let x = 10
  >   let result = x + 1
  > EOF
  $ dune exec sylic -- core test_shadow_nested.sy
  module Test_shadow_nested
  let syliTest_shadow_nested.x = 5 : i64
  
  let syliTest_shadow_nested.apply = fun () : i64 ->
      {
        let syliTest_shadow_nested.apply__x = 10 : i64
        let syliTest_shadow_nested.apply__result = (syliTest_shadow_nested.apply__x : i64 + 1 : i64) : i64
      }
  

Function with arguments
  $ cat >test_args.sy <<EOF
  > let add x y = x + y
  > let result = add 3 4
  > EOF
  $ dune exec sylic -- core test_args.sy
  module Test_args
  let syliTest_args.add = fun (x, y) : 'a28 ->
      (x : 'a28 + y : 'a28) : 'a28
  
  let syliTest_args.result = syliTest_args.add(3 : i64, 4 : i64) : i64
  


Nested functions with captured variables:
  $ cat >test_nested.sy <<EOF
  > let outer x =
  >   let inner y = x + y
  >   inner
  > let add_five = outer 5
  > let result = add_five 10
  > EOF
  $ dune exec sylic -- core test_nested.sy
  module Test_nested
  let syliTest_nested.outer = fun (x) : ('a44) -> 'a44 ->
      {
        let syliTest_nested.outer__inner = fun (y) : 'a41 ->
            (x : 'a41 + y : 'a41) : 'a41
        syliTest_nested.outer__inner : ('a44) -> 'a44
      }
  
  let syliTest_nested.add_five = syliTest_nested.outer(5 : i64) : ('a47) -> 'a47
  
  let syliTest_nested.result = syliTest_nested.add_five(10 : i64) : i64
  

Simple nested function without captured variables:
  $ cat >test_nested_simple.sy <<EOF
  > let y = 10
  > let outer x =
  >   let inner y = y + x + 1
  >   inner 2
  > EOF
  $ dune exec sylic -- core test_nested_simple.sy
  module Test_nested_simple
  let syliTest_nested_simple.y = 10 : i64
  
  let syliTest_nested_simple.outer = fun (x) : i64 ->
      {
        let syliTest_nested_simple.outer__inner = fun (y) : i64 ->
            ((y : i64 + x : i64) : i64 + 1 : i64) : i64
        syliTest_nested_simple.outer__inner(2 : i64) : i64
      }
  


Toplevel free variable capture:
  $ cat >test_toplevel_capture.sy <<EOF
  > let x = 5
  > let add_to_x y = x + y
  > let result = add_to_x 10
  > EOF
  $ dune exec sylic -- core test_toplevel_capture.sy
  module Test_toplevel_capture
  let syliTest_toplevel_capture.x = 5 : i64
  
  let syliTest_toplevel_capture.add_to_x = fun (y) : i64 ->
      (syliTest_toplevel_capture.x : i64 + y : i64) : i64
  
  let syliTest_toplevel_capture.result = syliTest_toplevel_capture.add_to_x(10 : i64) : i64
  

Simple 2 nested functions with the same name:
  $ cat >test_nested_simple.sy <<EOF
  > let y = 10
  > let outer x =
  >   let inner y = y + x + 1
  >   let inner z =
  >     let inner w = w + z + 2
  >     let inner w = w + z + 3
  > EOF
  $ dune exec sylic -- core test_nested_simple.sy
  module Test_nested_simple
  let syliTest_nested_simple.y = 10 : i64
  
  let syliTest_nested_simple.outer = fun (x) : (i64) -> (i64) -> i64 ->
      {
        let syliTest_nested_simple.outer__inner = fun (y) : i64 ->
            ((y : i64 + x : i64) : i64 + 1 : i64) : i64
        let syliTest_nested_simple.outer__inner#1 = fun (z) : (i64) -> i64 ->
            {
              let syliTest_nested_simple.outer__inner__inner = fun (w) : i64 ->
                  ((w : i64 + z : i64) : i64 + 2 : i64) : i64
              let syliTest_nested_simple.outer__inner__inner#1 = fun (w) : i64 ->
                  ((w : i64 + z : i64) : i64 + 3 : i64) : i64
            }
      }
  


Closure as an argument:
  $ cat >test_multi.sy <<EOF
  > let add x y = x + y
  > let apply f x y = f x y
  > fn main () =
  >   let add_closure = add
  >   let result = apply add_closure 3 4
  > EOF
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  let syliTest_multi.add = fun (x, y) : 'a57 ->
      (x : 'a57 + y : 'a57) : 'a57
  
  let syliTest_multi.apply = fun (f, x, y) : 'a68 ->
      f(x : 'a62, y : 'a64) : 'a68
  
  let syliTest_multi.main = fun () : i64 ->
      {
        let syliTest_multi.main__add_closure = syliTest_multi.add : ('a71, 'a71) -> 'a71
        let syliTest_multi.main__result = syliTest_multi.apply(syliTest_multi.main__add_closure : (i64, i64) -> i64, 3 : i64, 4 : i64) : i64
      }
  

Closure as an argument:
  $ cat >test_multi.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > let add x y = x + y
  > let apply f x y = f x y
  > fn main () =
  >   let add_closure = add
  >   let result = apply add_closure 3 4
  > EOF
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  let syliTest_multi.add = fun (x, y) : 'a63 ->
      (x : 'a63 + y : 'a63) : 'a63
  
  let syliTest_multi.apply = fun (f, x, y) : 'a74 ->
      f(x : 'a68, y : 'a70) : 'a74
  
  let syliTest_multi.main = fun () : i64 ->
      {
        let syliTest_multi.main__add_closure = syliTest_multi.add : ('a77, 'a77) -> 'a77
        let syliTest_multi.main__result = syliTest_multi.apply(syliTest_multi.main__add_closure : (i64, i64) -> i64, 3 : i64, 4 : i64) : i64
      }
  

Closure as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > let apply f x y = f x y
  > let add x y = x + y
  > fn main () =
  >   let result = apply add  3 4
  > EOF
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  let syliTest_multi.apply = fun (f, x, y) : 'a57 ->
      f(x : 'a51, y : 'a53) : 'a57
  
  let syliTest_multi.add = fun (x, y) : 'a61 ->
      (x : 'a61 + y : 'a61) : 'a61
  
  let syliTest_multi.main = fun () : i64 ->
      let syliTest_multi.main__result = syliTest_multi.apply(syliTest_multi.add : (i64, i64) -> i64, 3 : i64, 4 : i64) : i64
  


Closure Lambda as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > let apply f x y = f x y
  > fn main () =
  >   let result = apply (lambda a b -> a + b) 3 4
  > EOF
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  let syliTest_multi.apply = fun (f, x, y) : 'a52 ->
      f(x : 'a46, y : 'a48) : 'a52
  
  let syliTest_multi.main = fun () : i64 ->
      let syliTest_multi.main__result = syliTest_multi.apply(fun (a, b) : i64 ->
          (a : i64 + b : i64) : i64, 3 : i64, 4 : i64) : i64
  

Closure Lambda as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > let apply f x y = f x y
  > fn main () =
  >   let add a b = a + b
  >   let result = apply add 3 4
  > EOF
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  let syliTest_multi.apply = fun (f, x, y) : 'a58 ->
      f(x : 'a52, y : 'a54) : 'a58
  
  let syliTest_multi.main = fun () : i64 ->
      {
        let syliTest_multi.main__add = fun (a, b) : 'a63 ->
            (a : 'a63 + b : 'a63) : 'a63
        let syliTest_multi.main__result = syliTest_multi.apply(syliTest_multi.main__add : (i64, i64) -> i64, 3 : i64, 4 : i64) : i64
      }
  


TODO: 'apply' function does not exist, this should be error instead.
Closure Lambda as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > fn main () =
  >   let result = apply (lambda a b -> a + b) 3 4
  >   2
  > EOF
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  let syliTest_multi.main = fun () : i64 ->
      {
        let syliTest_multi.main__result = apply(fun (a, b) : 'a34 ->
            (a : 'a34 + b : 'a34) : 'a34, 3 : i64, 4 : i64) : 'a39
        2 : i64
      }
  
