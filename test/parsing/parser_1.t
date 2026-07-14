  $ cat >parse0.src <<EOF
  > let x = 10
  > EOF
  $ cat parse0.src
  let x = 10
  $ dune exec sylic parse parse0.src
  Parsed parse0.src
  let x = 10
  $ dune exec sylic parse parse0.src
  Parsed parse0.src
  let x = 10

  $ cat >parse0.src <<EOF
  > let x = 10
  > EOF
  $ cat parse0.src
  let x = 10
  $ dune exec sylic parse parse0.src
  Parsed parse0.src
  let x = 10


  $ cat >parse0.src <<EOF
  > let x = 10 + 7
  > let y = 20 - 3
  > EOF
  $ cat parse0.src
  let x = 10 + 7
  let y = 20 - 3
  $ dune exec sylic parse parse0.src
  Parsed parse0.src
  let x = (10 + 7)
  let y = (20 - 3)

  $ cat >parse0.src <<EOF
  > let x = (10, 20)
  > let y = (20, 30, 40)
  > let z = (x, y)
  > EOF
  $ cat parse0.src
  let x = (10, 20)
  let y = (20, 30, 40)
  let z = (x, y)
  $ dune exec sylic parse parse0.src
  Parsed parse0.src
  let x = (10, 20)
  let y = (20, 30, 40)
  let z = (x, y)

  $ cat >parse0.src <<EOF
  > x = 10
  > EOF
  $ cat parse0.src
  x = 10
  $ dune exec sylic parse parse0.src
  
  Parse error in parse0.src at line 1, column 0
  
    1 | x = 10
         ^^^^^^^^
  
  Unexpected token: 'IDENT(x)'
  
  [1]

  $ cat >parse0.src <<EOF
  > 4 + 5
  > 3 / 0
  > EOF
  $ cat parse0.src
  4 + 5
  3 / 0
  $ dune exec sylic parse parse0.src
  
  Parse error in parse0.src at line 1, column 0
  
    1 | 4 + 5
         ^^^^^^
  
  Unexpected token: 'INT(4)'
  
  [1]
  $ dune exec sylic parse parse0.src
  
  Parse error in parse0.src at line 1, column 0
  
    1 | 4 + 5
         ^^^^^^
  
  Unexpected token: 'INT(4)'
  
  [1]

  $ cat >parse0.src <<EOF 
  > local
  >    print_int_f(2)
  > end
  > print_int_s(3)
  > EOF
  $ cat parse0.src
  local
     print_int_f(2)
  end
  print_int_s(3)

  $ dune exec sylic parse parse0.src
  
  Parse error in parse0.src at line 1, column 0
  
    1 | local
         ^^^^^
  
  Unexpected token: 'LOCAL'
  
  [1]

  $ cat >parse0.src <<EOF
  > let x = 10
  > if x == 10 then
  >   print_int(1)
  > else 
  >   print_int(0)
  > end
  > EOF
  $ cat parse0.src
  let x = 10
  if x == 10 then
    print_int(1)
  else 
    print_int(0)
  end
  $ dune exec sylic parse parse0.src
  
  Parse error in parse0.src at line 2, column 0
  
    2 | if x == 10 then
         ^^
  
  Unexpected token: 'IF'
  
  [1]

  $ cat >parse0.src <<EOF
  > local
  >     local
  >       let x = 10
  >       x + 5
  >     end
  > end
  > print_int(2)
  > EOF
  $ cat parse0.src
  local
      local
        let x = 10
        x + 5
      end
  end
  print_int(2)
  $ dune exec sylic parse parse0.src
  
  Parse error in parse0.src at line 1, column 0
  
    1 | local
         ^^^^^
  
  Unexpected token: 'LOCAL'
  
  [1]

  $ cat >parse0.src <<EOF
  > let x =
  >     local
  >       let x = 10
  >       x + 5
  >     end
  > end
  > print_int(x)
  > EOF
  $ cat parse0.src
  let x =
      local
        let x = 10
        x + 5
      end
  end
  print_int(x)
  $ dune exec sylic parse parse0.src
  
  Parse error in parse0.src at line 7, column 0
  
    7 | print_int(x)
         ^^^^^^^^^^^^^^^^
  
  Unexpected token: 'IDENT(print_int)'
  
  [1]

  $ cat >parse0.src <<EOF
  > let x =
  >       let x = 10
  >       x + 5
  > end
  > print_int(x)
  > EOF
  $ cat parse0.src
  let x =
        let x = 10
        x + 5
  end
  print_int(x)
  $ dune exec sylic parse parse0.src
  
  Parse error in parse0.src at line 5, column 0
  
    5 | print_int(x)
         ^^^^^^^^^^^^^^^^
  
  Unexpected token: 'IDENT(print_int)'
  
  [1]

  $ cat >parse0.src <<EOF
  > let mut x = 0
  > while x < 10
  >   x = x + 1
  > end
  > print_int(x)
  > EOF
  $ cat parse0.src
  let mut x = 0
  while x < 10
    x = x + 1
  end
  print_int(x)
  $ dune exec sylic parse parse0.src
  
  Parse error in parse0.src at line 1, column 4
  
    1 | let mut x = 0
             ^^^
  
  Unexpected token: 'MUT'
  
  [1]

  $ cat >parse0.src <<EOF
  > let x =
  >     let x = 10
  >     x + 5
  >     x + 5
  > end
  > print_int(x)
  > EOF
  $ cat parse0.src
  let x =
      let x = 10
      x + 5
      x + 5
  end
  print_int(x)
  $ dune exec sylic parse parse0.src
  
  Parse error in parse0.src at line 6, column 0
  
    6 | print_int(x)
         ^^^^^^^^^^^^^^^^
  
  Unexpected token: 'IDENT(print_int)'
  
  [1]

  $ dune exec sylic parse parse0.src
  
  Parse error in parse0.src at line 6, column 0
  
    6 | print_int(x)
         ^^^^^^^^^^^^^^^^
  
  Unexpected token: 'IDENT(print_int)'
  
  [1]

  $ cat >parse0.src <<EOF
  > fn add (a) = a + 5
  > print_int (add(10))
  > EOF
  $ cat parse0.src
  fn add (a) = a + 5
  print_int (add(10))
  $ dune exec sylic parse parse0.src
  
  Parse error in parse0.src at line 2, column 0
  
    2 | print_int (add(10))
         ^^^^^^^^^^^^^^^^
  
  Unexpected token: 'IDENT(print_int)'
  
  [1]
