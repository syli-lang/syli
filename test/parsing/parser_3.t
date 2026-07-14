
  $ cat >parse0.src <<EOF
  > let x = 10
  > match x with
  > | 10 -> print_int(1)
  > | _ -> 
  >   print_int(0)
  > print_int(5)
  > EOF
  $ cat parse0.src
  let x = 10
  match x with
  | 10 -> print_int(1)
  | _ -> 
    print_int(0)
  print_int(5)
  $ dune exec sylic parse parse0.src
  
  Parse error in parse0.src at line 2, column 0
  
    2 | match x with
         ^^^^^
  
  Unexpected token: 'MATCH'
  
  [1]

  $ cat >parse0.src <<EOF
  > let rec factorial n =
  >   if n == 0 then
  >     1
  >   else
  >     n * factorial (n - 1)
  > end
  > EOF
  $ cat parse0.src
  let rec factorial n =
    if n == 0 then
      1
    else
      n * factorial (n - 1)
  end
  $ dune exec sylic parse parse0.src
  Parsed parse0.src
  let factorial = lambda(n) {
    if (n == 0) {
      1
    } else {
      (n * factorial((n - 1)))
    }
  }
