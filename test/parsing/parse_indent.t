  $ cat >parse0.src <<EOF
  > fn add () =
  >     let record = { name =  "test"; value = 5 }
  >     let n = record.value
  >     record.value = 10
  >     print_int(5)
  > end
  > let _ = 
  >     print_int (add ())
  > EOF
  $ dune exec sylic parse parse0.src
  Parsed parse0.src
  fn add = lambda(()) {
    {
      let record = { name = "test"; value = 5 };
      let n = record.value;
      record.value = 10;
      print_int(5)
    }
  }
  let _ = print_int(add(()))


  $ cat >parse0.src <<EOF
  > fn add () =
  >     let record = { name =  "test"; value = 5 }
  >           let n = record.value
  >     record.value = 10
  >     print_int(5)
  > end
  > let _ = 
  >     print_int (add ())
  > EOF
  $ dune exec sylic parse parse0.src
  
  Parse error in parse0.src at line 3, column 0
  
    3 |           let n = record.value
         ^^^^^^
  
  Unexpected token: 'INDENT'
  
  [1]


  $ cat >parse0.src <<EOF
  > fn add () =
  >     let record = 
  >     {
  >         name = "test"; value = 5 
  >     }
  >     let n = record.value
  >       record.value = 10
  >     print_int(5)
  > end
  > let _ = 
  >     print_int (add ())
  > EOF
  $ dune exec sylic parse parse0.src
  
  Parse error in parse0.src at line 7, column 0
  
    7 |       record.value = 10
         ^^^^^^
  
  Unexpected token: 'INDENT'
  
  [1]


  $ cat >parse0.src <<EOF
  > fn add () =
  >     let record = 
  >     [|
  >       2,
  >       3,
  >       4,
  >       5
  >     |] 
  >     let n = record.value
  >       record.value = 10
  >     print_int(5)
  > end
  > let _ = 
  >     print_int (add ())
  > EOF
  $ dune exec sylic parse parse0.src
  
  Parse error in parse0.src at line 3, column 4
  
    3 |     [|
             ^^^^^^^^^^^^
  
  Unexpected token: 'LBRACKET_BAR'
  
  [1]


Closure with multipble chains of captured variables:
  $ cat >test_multi.sy <<EOF
  > let apply =
  >   let result = 2
  >   result
  > let m = result
  > EOF
  $ dune exec sylic -- parse test_multi.sy
  Parsed test_multi.sy
  let apply = {
    let result = 2;
    result
  }
  let m = result


Closure as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > fn main () =
  >   let add2 =
  >     if true then
  >       3
  >     else
  >       4
  >   let result2 = 4 
  >   result2
  > EOF
  $ dune exec sylic -- parse test_multi.sy
  Parsed test_multi.sy
  fn main = lambda(()) {
    {
      let add2 = if true then
                   3
                   else
                   4;
      let result2 = 4;
      result2
    }
  }
