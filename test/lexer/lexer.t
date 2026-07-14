  $ cat >parse0.src <<EOF
  > let x = ref 10
  > EOF
  $ cat parse0.src
  let x = ref 10
  $ dune exec sylic lex parse0.src
  LET
  IDENT(x)
  EQ
  IDENT(ref)
  INT(10)
  NEWLINE
  EOF

  $ cat >parse0.src <<EOF
  > let x = 10
  > EOF
  $ cat parse0.src
  let x = 10
  $ dune exec sylic lex parse0.src
  LET
  IDENT(x)
  EQ
  INT(10)
  NEWLINE
  EOF

  $ cat >parse0.src <<EOF
  > let x = (10, 20)
  > let y = (20, 30, 40)
  > let z = (x, y)
  > EOF
  $ cat parse0.src
  let x = (10, 20)
  let y = (20, 30, 40)
  let z = (x, y)
  $ dune exec sylic lex parse0.src
  LET
  IDENT(x)
  EQ
  LPAREN
  INT(10)
  COMMA
  INT(20)
  RPAREN
  NEWLINE
  LET
  IDENT(y)
  EQ
  LPAREN
  INT(20)
  COMMA
  INT(30)
  COMMA
  INT(40)
  RPAREN
  NEWLINE
  LET
  IDENT(z)
  EQ
  LPAREN
  IDENT(x)
  COMMA
  IDENT(y)
  RPAREN
  NEWLINE
  EOF

  $ cat >parse0.src <<EOF 
  > local:
  >    print_int 2
  > print_int 3
  > EOF
  $ cat parse0.src
  local:
     print_int 2
  print_int 3
  $ dune exec sylic lex parse0.src
  LOCAL
  COLON
  NEWLINE
  INDENT
  IDENT(print_int)
  INT(2)
  NEWLINE
  DEDENT
  IDENT(print_int)
  INT(3)
  NEWLINE
  EOF

  $ cat >parse0.src <<EOF
  > let x = 10
  > if x == 10:
  >   print_int 1
  > else: 
  >  print_int 0
  > end
  > EOF
  $ cat parse0.src
  let x = 10
  if x == 10:
    print_int 1
  else: 
   print_int 0
  end
  $ dune exec sylic lex parse0.src
  LET
  IDENT(x)
  EQ
  INT(10)
  NEWLINE
  IF
  IDENT(x)
  EQEQ
  INT(10)
  COLON
  NEWLINE
  INDENT
  IDENT(print_int)
  INT(1)
  NEWLINE
  DEDENT
  ELSE
  COLON
  NEWLINE
  INDENT
  IDENT(print_int)
  INT(0)
  NEWLINE
  DEDENT
  END
  NEWLINE
  EOF

  $ cat >parse0.src <<EOF
  > local:
  >     local:
  >       let x = 10
  >       x + 5
  >     end
  > end
  > print_int 2
  > EOF
  $ cat parse0.src
  local:
      local:
        let x = 10
        x + 5
      end
  end
  print_int 2
  $ dune exec sylic lex parse0.src
  LOCAL
  COLON
  NEWLINE
  INDENT
  LOCAL
  COLON
  NEWLINE
  INDENT
  LET
  IDENT(x)
  EQ
  INT(10)
  NEWLINE
  IDENT(x)
  PLUS
  INT(5)
  NEWLINE
  DEDENT
  END
  NEWLINE
  DEDENT
  END
  NEWLINE
  IDENT(print_int)
  INT(2)
  NEWLINE
  EOF

  $ cat >parse0.src <<EOF
  > let x =
  >     local:
  >       let x = 10
  >       x + 5
  >     end
  > end
  > print_int x
  > EOF
  $ cat parse0.src
  let x =
      local:
        let x = 10
        x + 5
      end
  end
  print_int x
  $ dune exec sylic lex parse0.src
  LET
  IDENT(x)
  EQ
  NEWLINE
  INDENT
  LOCAL
  COLON
  NEWLINE
  INDENT
  LET
  IDENT(x)
  EQ
  INT(10)
  NEWLINE
  IDENT(x)
  PLUS
  INT(5)
  NEWLINE
  DEDENT
  END
  NEWLINE
  DEDENT
  END
  NEWLINE
  IDENT(print_int)
  IDENT(x)
  NEWLINE
  EOF

  $ cat >parse0.src <<EOF
  > let x =
  >       let x = 10
  >       x + 5
  > end
  > print_int x
  > EOF
  $ cat parse0.src
  let x =
        let x = 10
        x + 5
  end
  print_int x
  $ dune exec sylic lex parse0.src
  LET
  IDENT(x)
  EQ
  NEWLINE
  INDENT
  LET
  IDENT(x)
  EQ
  INT(10)
  NEWLINE
  IDENT(x)
  PLUS
  INT(5)
  NEWLINE
  DEDENT
  END
  NEWLINE
  IDENT(print_int)
  IDENT(x)
  NEWLINE
  EOF

  $ cat >parse0.src <<EOF
  > let mut x = 0
  > while x < 10:
  >   x = x + 1
  > end
  > print_int x
  > EOF
  $ cat parse0.src
  let mut x = 0
  while x < 10:
    x = x + 1
  end
  print_int x
  $ dune exec sylic lex parse0.src
  LET
  MUT
  IDENT(x)
  EQ
  INT(0)
  NEWLINE
  WHILE
  IDENT(x)
  LT
  INT(10)
  COLON
  NEWLINE
  INDENT
  IDENT(x)
  EQ
  IDENT(x)
  PLUS
  INT(1)
  NEWLINE
  DEDENT
  END
  NEWLINE
  IDENT(print_int)
  IDENT(x)
  NEWLINE
  EOF

  $ cat >parse0.src <<EOF
  > let x =
  >     let x = 10; x + 5
  >     x + 5
  > end
  > print_int x
  > EOF
  $ cat parse0.src
  let x =
      let x = 10; x + 5
      x + 5
  end
  print_int x
  $ dune exec sylic lex parse0.src
  LET
  IDENT(x)
  EQ
  NEWLINE
  INDENT
  LET
  IDENT(x)
  EQ
  INT(10)
  SEMI
  IDENT(x)
  PLUS
  INT(5)
  NEWLINE
  IDENT(x)
  PLUS
  INT(5)
  NEWLINE
  DEDENT
  END
  NEWLINE
  IDENT(print_int)
  IDENT(x)
  NEWLINE
  EOF

  $ cat >parse0.src <<EOF
  > fn add a b =
  >  let c = 0
  >     a + b
  > end
  > EOF
  $ cat parse0.src
  fn add a b =
   let c = 0
      a + b
  end
  $ dune exec sylic lex parse0.src
  FN
  IDENT(add)
  IDENT(a)
  IDENT(b)
  EQ
  NEWLINE
  INDENT
  LET
  IDENT(c)
  EQ
  INT(0)
  NEWLINE
  INDENT
  IDENT(a)
  PLUS
  IDENT(b)
  NEWLINE
  DEDENT
  DEDENT
  END
  NEWLINE
  EOF

  $ cat >parse0.src <<EOF
  > fn add:
  >  print_int 5
  > end
  > EOF
  $ cat parse0.src
  fn add:
   print_int 5
  end
  $ dune exec sylic lex parse0.src
  FN
  IDENT(add)
  COLON
  NEWLINE
  INDENT
  IDENT(print_int)
  INT(5)
  NEWLINE
  DEDENT
  END
  NEWLINE
  EOF

  $ cat >parse0.src <<EOF
  > fn add a =
  >   a + 5
  > print_int (add 10)
  > end
  > EOF
  $ cat parse0.src
  fn add a =
    a + 5
  print_int (add 10)
  end
  $ dune exec sylic lex parse0.src
  FN
  IDENT(add)
  IDENT(a)
  EQ
  NEWLINE
  INDENT
  IDENT(a)
  PLUS
  INT(5)
  NEWLINE
  DEDENT
  IDENT(print_int)
  LPAREN
  IDENT(add)
  INT(10)
  RPAREN
  NEWLINE
  END
  NEWLINE
  EOF
