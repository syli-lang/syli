Core AST pretty printing

Integer and boolean literals:
  $ cat >test_core_basic.sy <<EOF
  > primitive (+)  : i64 -> i64 -> i64 = "add"
  > let x = 42
  > let y = x + 10
  > let b = true
  > EOF
  $ dune exec sylic core test_core_basic.sy
  module Test_core_basic
  extern "syliTest_core_basic.+" : (i64) -> (i64) -> i64
  
  let syliTest_core_basic.x = 42 : i64
  
  let syliTest_core_basic.y = "syliTest_core_basic.+"(syliTest_core_basic.x : i64, 10 : i64) : i64
  
  let syliTest_core_basic.b = true : bool
  
If expression:
  $ cat >test_core_if.sy <<EOF
  > primitive (>)  : i64 -> i64 -> bool = "gt"
  > let x = 10
  > let y = if x > 5 then 1 else 0
  > EOF
  $ dune exec sylic core test_core_if.sy
  module Test_core_if
  extern "syliTest_core_if.>" : (i64) -> (i64) -> bool
  
  let syliTest_core_if.x = 10 : i64
  
  let syliTest_core_if.y = if "syliTest_core_if.>"(syliTest_core_if.x : i64, 5 : i64) : bool
      1 : i64
    else
      0 : i64
  

Use of foreignal function and record creation:
  $ cat >test_e2e_print.sy <<EOF
  > foreign syli_print_i64 : i64 -> unit = "syli_print_i64"
  > type person = { name: i64; age: i64 }
  > let main () =
  >     let record = { name = 10; age = 30 }
  >     syli_print_i64(record.age)
  > EOF
  $ dune exec sylic -- core test_e2e_print.sy
  module Test_e2e_print
  extern syliTest_e2e_print.syli_print_i64 : (i64) -> unit
  
  type syliTest_e2e_print.person = { 0 : i64; 1 : i64 }
  
  let syliTest_e2e_print.main = fun () : unit ->
      {
        let sy1_record = { 0 = 10 : i64; 1 = 30 : i64 } : syliTest_e2e_print.person
        syliTest_e2e_print.syli_print_i64(sy1_record.1 : i64) : unit
      }
  
Use of foreignal function and record creation:
  $ cat >test_e2e_print.sy <<EOF
  > foreign syli_print_i64 : i64 -> unit = "syli_print_i64"
  > type person = { name: i64; age: i64 }
  > let main () =
  >     let record = { name = 10; age = 30 }
  > EOF
  $ dune exec sylic -- core test_e2e_print.sy
  module Test_e2e_print
  extern syliTest_e2e_print.syli_print_i64 : (i64) -> unit
  
  type syliTest_e2e_print.person = { 0 : i64; 1 : i64 }
  
  let syliTest_e2e_print.main = fun () : unit ->
      let sy1_record = { 0 = 10 : i64; 1 = 30 : i64 } : syliTest_e2e_print.person
  
Record literal with fields in a different order than the declaration:
  $ cat >test_e2e_print.sy <<EOF
  > foreign syli_print_i64 : i64 -> unit = "syli_print_i64"
  > type person = { name: i64; age: i64 }
  > let main () =
  >     let record = { age = 30; name = 10 }
  >     syli_print_i64(record.name)
  > EOF
  $ dune exec sylic -- core test_e2e_print.sy
  module Test_e2e_print
  extern syliTest_e2e_print.syli_print_i64 : (i64) -> unit
  
  type syliTest_e2e_print.person = { 0 : i64; 1 : i64 }
  
  let syliTest_e2e_print.main = fun () : unit ->
      {
        let sy1_record = { 1 = 30 : i64; 0 = 10 : i64 } : syliTest_e2e_print.person
        syliTest_e2e_print.syli_print_i64(sy1_record.0 : i64) : unit
      }
  

Closures as an argument:
  $ cat >test_closure.src <<EOF
  > primitive (+)  : i64 -> i64 -> i64 = "add"
  > let apply_twice f x = f (f x)
  > let double_x x = x + x
  > let result = apply_twice double_x 10
  > EOF
  $ dune exec sylic -- core test_closure.src
  module Test_closure
  extern "syliTest_closure.+" : (i64) -> (i64) -> i64
  
  let syliTest_closure.apply_twice = fun (f, x) : 'a54 ->
      f(f(x : 'a54) : 'a54) : 'a54
  
  let syliTest_closure.double_x = fun (x) : i64 ->
      "syliTest_closure.+"(x : i64, x : i64) : i64
  
  let syliTest_closure.result = syliTest_closure.apply_twice(syliTest_closure.double_x : (i64) -> i64, 10 : i64) : i64
  

Closure with multipble chains of captured variables:
  $ cat >test_multi.sy <<EOF
  > primitive (+)  : i64 -> i64 -> i64 = "add"
  > let add x y z = x + y + z
  > let apply () =
  >   let add1 = add 1
  >   let add1and2 = add1 2
  >   let result = add1and2 3
  > EOF
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  extern "syliTest_multi.+" : (i64) -> (i64) -> i64
  
  let syliTest_multi.add = fun (x, y, z) : i64 ->
      "syliTest_multi.+"("syliTest_multi.+"(x : i64, y : i64) : i64, z : i64) : i64
  
  let syliTest_multi.apply = fun () : unit ->
      {
        let sy1_add1 = syliTest_multi.add(1 : i64) : (i64) -> (i64) -> i64
        let sy2_add1and2 = sy1_add1(2 : i64) : (i64) -> i64
        let sy3_result = sy2_add1and2(3 : i64) : i64
      }
  


Overriding same name variable in the top-level scope:
  $ cat >test_shadow.sy <<EOF
  > primitive (+)  : i64 -> i64 -> i64 = "add"
  > let x = 5
  > let y = x + 1
  > let x = 10
  > let result = x + 1
  > EOF
  $ dune exec sylic -- core test_shadow.sy
  module Test_shadow
  extern "syliTest_shadow.+" : (i64) -> (i64) -> i64
  
  let syliTest_shadow.x = 5 : i64
  
  let syliTest_shadow.y = "syliTest_shadow.+"(syliTest_shadow.x : i64, 1 : i64) : i64
  
  let syliTest_shadow.x = 10 : i64
  
  let syliTest_shadow.result = "syliTest_shadow.+"(syliTest_shadow.x : i64, 1 : i64) : i64
  

Overriding a param in the function body:
  $ cat >test_shadow_nested.sy <<EOF
  > primitive (+)  : i64 -> i64 -> i64 = "add"
  > let apply x =
  >   let x = 10
  >   let result = x + 1
  > EOF
  $ dune exec sylic -- core test_shadow_nested.sy  
  module Test_shadow_nested
  extern "syliTest_shadow_nested.+" : (i64) -> (i64) -> i64
  
  let syliTest_shadow_nested.apply = fun (x) : unit ->
      {
        let sy1_x = 10 : i64
        let sy2_result = "syliTest_shadow_nested.+"(sy1_x : i64, 1 : i64) : i64
      }
  

Overriding same name variable in a nested scope:
  $ cat >test_shadow_nested.sy <<EOF
  > primitive (+)  : i64 -> i64 -> i64 = "add"
  > let x = 5
  > let apply () =
  >   let x = 10
  >   let result = x + 1
  > EOF
  $ dune exec sylic -- core test_shadow_nested.sy
  module Test_shadow_nested
  extern "syliTest_shadow_nested.+" : (i64) -> (i64) -> i64
  
  let syliTest_shadow_nested.x = 5 : i64
  
  let syliTest_shadow_nested.apply = fun () : unit ->
      {
        let sy1_x = 10 : i64
        let sy2_result = "syliTest_shadow_nested.+"(sy1_x : i64, 1 : i64) : i64
      }
  

Function with arguments
  $ cat >test_args.sy <<EOF
  > primitive (+)  : i64 -> i64 -> i64 = "add"
  > let add x y = x + y
  > let result = add 3 4
  > EOF
  $ dune exec sylic -- core test_args.sy
  module Test_args
  extern "syliTest_args.+" : (i64) -> (i64) -> i64
  
  let syliTest_args.add = fun (x, y) : i64 ->
      "syliTest_args.+"(x : i64, y : i64) : i64
  
  let syliTest_args.result = syliTest_args.add(3 : i64, 4 : i64) : i64
  


Nested functions with captured variables:
  $ cat >test_nested.sy <<EOF
  > primitive (+)  : i64 -> i64 -> i64 = "add"
  > let outer x =
  >   let inner y = x + y
  >   inner
  > let add_five = outer 5
  > let result = add_five 10
  > EOF
  $ dune exec sylic -- core test_nested.sy
  module Test_nested
  extern "syliTest_nested.+" : (i64) -> (i64) -> i64
  
  let syliTest_nested.outer = fun (x) : (i64) -> i64 ->
      {
        let sy1_inner = fun (y) : i64 ->
            "syliTest_nested.+"(x : i64, y : i64) : i64
        sy1_inner : (i64) -> i64
      }
  
  let syliTest_nested.add_five = syliTest_nested.outer(5 : i64) : (i64) -> i64
  
  let syliTest_nested.result = syliTest_nested.add_five(10 : i64) : i64
  

Simple nested function without captured variables:
  $ cat >test_nested_simple.sy <<EOF
  > primitive (+)  : i64 -> i64 -> i64 = "add"
  > let y = 10
  > let outer x =
  >   let inner y = y + x + 1
  >   inner 2
  > EOF
  $ dune exec sylic -- core test_nested_simple.sy
  module Test_nested_simple
  extern "syliTest_nested_simple.+" : (i64) -> (i64) -> i64
  
  let syliTest_nested_simple.y = 10 : i64
  
  let syliTest_nested_simple.outer = fun (x) : i64 ->
      {
        let sy1_inner = fun (y) : i64 ->
            "syliTest_nested_simple.+"("syliTest_nested_simple.+"(y : i64, x : i64) : i64, 1 : i64) : i64
        sy1_inner(2 : i64) : i64
      }
  


Toplevel free variable capture:
  $ cat >test_toplevel_capture.sy <<EOF
  > primitive (+)  : i64 -> i64 -> i64 = "add"
  > let x = 5
  > let add_to_x y = x + y
  > let result = add_to_x 10
  > EOF
  $ dune exec sylic -- core test_toplevel_capture.sy
  module Test_toplevel_capture
  extern "syliTest_toplevel_capture.+" : (i64) -> (i64) -> i64
  
  let syliTest_toplevel_capture.x = 5 : i64
  
  let syliTest_toplevel_capture.add_to_x = fun (y) : i64 ->
      "syliTest_toplevel_capture.+"(syliTest_toplevel_capture.x : i64, y : i64) : i64
  
  let syliTest_toplevel_capture.result = syliTest_toplevel_capture.add_to_x(10 : i64) : i64
  

Simple 2 nested functions with the same name:
  $ cat >test_nested_simple.sy <<EOF
  > primitive (+)  : i64 -> i64 -> i64 = "add"
  > let y = 10
  > let outer x =
  >   let inner y = y + x + 1
  >   let inner z =
  >     let inner w = w + z + 2
  >     let inner w = w + z + 3
  > EOF
  $ dune exec sylic -- core test_nested_simple.sy
  module Test_nested_simple
  extern "syliTest_nested_simple.+" : (i64) -> (i64) -> i64
  
  let syliTest_nested_simple.y = 10 : i64
  
  let syliTest_nested_simple.outer = fun (x) : unit ->
      {
        let sy1_inner = fun (y) : i64 ->
            "syliTest_nested_simple.+"("syliTest_nested_simple.+"(y : i64, x : i64) : i64, 1 : i64) : i64
        let sy2_inner = fun (z) : unit ->
            {
              let sy3_inner = fun (w) : i64 ->
                  "syliTest_nested_simple.+"("syliTest_nested_simple.+"(w : i64, z : i64) : i64, 2 : i64) : i64
              let sy4_inner = fun (w) : i64 ->
                  "syliTest_nested_simple.+"("syliTest_nested_simple.+"(w : i64, z : i64) : i64, 3 : i64) : i64
            }
      }
  

Non-recursive let shadowing a recursive function parameter:
  $ cat >test_shadow_param.sy <<EOF
  > primitive (-)  : i64 -> i64 -> i64 = "sub"
  > primitive (+)  : i64 -> i64 -> i64 = "add"
  > primitive (==) : i64 -> i64 -> bool = "eq"
  > foreign syli_print_i64 : i64 -> unit = "syli_print_i64"
  > let rec countdown n =
  >   if n == 0 then
  >     0
  >   else
  >     let n = countdown (n - 1)
  >     n + 1
  > let main () = syli_print_i64(countdown 5)
  > EOF
  $ dune exec sylic -- core test_shadow_param.sy
  module Test_shadow_param
  extern "syliTest_shadow_param.-" : (i64) -> (i64) -> i64
  
  extern "syliTest_shadow_param.+" : (i64) -> (i64) -> i64
  
  extern "syliTest_shadow_param.==" : (i64) -> (i64) -> bool
  
  extern syliTest_shadow_param.syli_print_i64 : (i64) -> unit
  
  let rec syliTest_shadow_param.countdown = fun (n) : i64 ->
      if "syliTest_shadow_param.=="(n : i64, 0 : i64) : bool
        0 : i64
      else
        {
          let sy1_n = syliTest_shadow_param.countdown("syliTest_shadow_param.-"(n : i64, 1 : i64) : i64) : i64
          "syliTest_shadow_param.+"(sy1_n : i64, 1 : i64) : i64
        }
  
  let syliTest_shadow_param.main = fun () : unit ->
      syliTest_shadow_param.syli_print_i64(syliTest_shadow_param.countdown(5 : i64) : i64) : unit
  


  $ cat >test_param.sy <<EOF
  > foreign syli_print_i64 : i64 -> unit = "syli_print_i64"
  > primitive (==) : i64 -> i64 -> bool = "eq"
  > primitive (+)  : i64 -> i64 -> i64 = "add"
  > primitive (-)  : i64 -> i64 -> i64 = "sub"
  > let rec countdown n =
  >   if n == 0 then
  >     0
  >   else
  >     let n1 = countdown (n - 1)
  >     n1 + 1
  > let main () = syli_print_i64(countdown 5)
  > EOF
  $ dune exec sylic -- core test_param.sy
  module Test_param
  extern syliTest_param.syli_print_i64 : (i64) -> unit
  
  extern "syliTest_param.==" : (i64) -> (i64) -> bool
  
  extern "syliTest_param.+" : (i64) -> (i64) -> i64
  
  extern "syliTest_param.-" : (i64) -> (i64) -> i64
  
  let rec syliTest_param.countdown = fun (n) : i64 ->
      if "syliTest_param.=="(n : i64, 0 : i64) : bool
        0 : i64
      else
        {
          let sy1_n1 = syliTest_param.countdown("syliTest_param.-"(n : i64, 1 : i64) : i64) : i64
          "syliTest_param.+"(sy1_n1 : i64, 1 : i64) : i64
        }
  
  let syliTest_param.main = fun () : unit ->
      syliTest_param.syli_print_i64(syliTest_param.countdown(5 : i64) : i64) : unit
  
Closure as an argument:
  $ cat >test_multi.sy <<EOF
  > primitive (+)  : i64 -> i64 -> i64 = "add"
  > let add x y = x + y
  > let apply f x y = f x y
  > let main () =
  >   let add_closure = add
  >   let result = apply add_closure 3 4
  > EOF
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  extern "syliTest_multi.+" : (i64) -> (i64) -> i64
  
  let syliTest_multi.add = fun (x, y) : i64 ->
      "syliTest_multi.+"(x : i64, y : i64) : i64
  
  let syliTest_multi.apply = fun (f, x, y) : 'a78 ->
      f(x : 'a72, y : 'a74) : 'a78
  
  let syliTest_multi.main = fun () : unit ->
      {
        let sy1_add_closure = syliTest_multi.add : (i64) -> (i64) -> i64
        let sy2_result = syliTest_multi.apply(sy1_add_closure : (i64) -> (i64) -> i64, 3 : i64, 4 : i64) : i64
      }
  

Closure as an argument:
  $ cat >test_multi.sy <<EOF
  > foreign syli_print_i64 : i64 -> unit = "syli_print_i64"
  > primitive (+) : i64 -> i64 -> i64 = "add"
  > let add x y = x + y
  > let apply f x y = f x y
  > let main () =
  >   let add_closure = add
  >   let result = apply add_closure 3 4
  >   syli_print_i64 result
  > EOF
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  extern syliTest_multi.syli_print_i64 : (i64) -> unit
  
  extern "syliTest_multi.+" : (i64) -> (i64) -> i64
  
  let syliTest_multi.add = fun (x, y) : i64 ->
      "syliTest_multi.+"(x : i64, y : i64) : i64
  
  let syliTest_multi.apply = fun (f, x, y) : 'a88 ->
      f(x : 'a82, y : 'a84) : 'a88
  
  let syliTest_multi.main = fun () : unit ->
      {
        let sy1_add_closure = syliTest_multi.add : (i64) -> (i64) -> i64
        let sy2_result = syliTest_multi.apply(sy1_add_closure : (i64) -> (i64) -> i64, 3 : i64, 4 : i64) : i64
        syliTest_multi.syli_print_i64(sy2_result : i64) : unit
      }
  

Closure as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > primitive (+)  : i64 -> i64 -> i64 = "add"
  > let apply f x y = f x y
  > let add x y = x + y
  > let main () =
  >   let result = apply add  3 4
  > EOF
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  extern "syliTest_multi.+" : (i64) -> (i64) -> i64
  
  let syliTest_multi.apply = fun (f, x, y) : 'a67 ->
      f(x : 'a61, y : 'a63) : 'a67
  
  let syliTest_multi.add = fun (x, y) : i64 ->
      "syliTest_multi.+"(x : i64, y : i64) : i64
  
  let syliTest_multi.main = fun () : unit ->
      let sy1_result = syliTest_multi.apply(syliTest_multi.add : (i64) -> (i64) -> i64, 3 : i64, 4 : i64) : i64
  


Closure Lambda as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > primitive (+)  : i64 -> i64 -> i64 = "add"
  > let apply f x y = f x y
  > let main () =
  >   let result = apply (fun a b -> a + b) 3 4
  > EOF
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  extern "syliTest_multi.+" : (i64) -> (i64) -> i64
  
  let syliTest_multi.apply = fun (f, x, y) : 'a62 ->
      f(x : 'a56, y : 'a58) : 'a62
  
  let syliTest_multi.main = fun () : unit ->
      let sy1_result = syliTest_multi.apply(fun (a, b) : i64 ->
          "syliTest_multi.+"(a : i64, b : i64) : i64, 3 : i64, 4 : i64) : i64
  

Closure Lambda as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > primitive (+)  : i64 -> i64 -> i64 = "add"
  > let apply f x y = f x y
  > let main () =
  >   let add a b = a + b
  >   let result = apply add 3 4
  > EOF
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  extern "syliTest_multi.+" : (i64) -> (i64) -> i64
  
  let syliTest_multi.apply = fun (f, x, y) : 'a68 ->
      f(x : 'a62, y : 'a64) : 'a68
  
  let syliTest_multi.main = fun () : unit ->
      {
        let sy1_add = fun (a, b) : i64 ->
            "syliTest_multi.+"(a : i64, b : i64) : i64
        let sy2_result = syliTest_multi.apply(sy1_add : (i64) -> (i64) -> i64, 3 : i64, 4 : i64) : i64
      }
  

Closure Lambda as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > primitive (+)  : i64 -> i64 -> i64 = "add"
  > let apply f x y =  f x y
  > let main () =
  >   let result = apply (fun a b -> a + b) 3 4
  >   2
  > EOF
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  extern "syliTest_multi.+" : (i64) -> (i64) -> i64
  
  let syliTest_multi.apply = fun (f, x, y) : 'a65 ->
      f(x : 'a59, y : 'a61) : 'a65
  
  let syliTest_multi.main = fun () : i64 ->
      {
        let sy1_result = syliTest_multi.apply(fun (a, b) : i64 ->
            "syliTest_multi.+"(a : i64, b : i64) : i64, 3 : i64, 4 : i64) : i64
        2 : i64
      }
  
Simple tuple:
  $ cat >test_simple_tuple.sy <<EOF
  > let apply f x y =  f x y
  > let id x y = (x,y)
  > let _ = apply id 2 3
  > EOF
  $ dune exec sylic -- core test_simple_tuple.sy
  module Test_simple_tuple
  let syliTest_simple_tuple.apply = fun (f, x, y) : 'a53 ->
      f(x : 'a47, y : 'a49) : 'a53
  
  let syliTest_simple_tuple.id = fun (x, y) : ('a55 * 'a57) ->
      (x : 'a55, y : 'a57) : ('a55 * 'a57)
  
  let syliTest_simple_tuple.sy1_any_pat = syliTest_simple_tuple.apply(syliTest_simple_tuple.id : (i64) -> (i64) -> (i64 * i64), 2 : i64, 3 : i64) : (i64 * i64)
  
