  $ cat >parse0.src <<EOF
  > let x = ref 10
  > EOF
  $ cat parse0.src
  let x = ref 10
  $ dune exec sylic lex parse0.src
  LET
  IDENT(x)
  =
  REF
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
  =
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
  =
  (
  INT(10)
  ,
  INT(20)
  )
  NEWLINE
  LET
  IDENT(y)
  =
  (
  INT(20)
  ,
  INT(30)
  ,
  INT(40)
  )
  NEWLINE
  LET
  IDENT(z)
  =
  (
  IDENT(x)
  ,
  IDENT(y)
  )
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
  :
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
  =
  INT(10)
  NEWLINE
  IF
  IDENT(x)
  ==
  INT(10)
  :
  NEWLINE
  INDENT
  IDENT(print_int)
  INT(1)
  NEWLINE
  DEDENT
  ELSE
  :
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
  :
  NEWLINE
  INDENT
  LOCAL
  :
  NEWLINE
  INDENT
  LET
  IDENT(x)
  =
  INT(10)
  NEWLINE
  IDENT(x)
  +
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
  =
  NEWLINE
  INDENT
  LOCAL
  :
  NEWLINE
  INDENT
  LET
  IDENT(x)
  =
  INT(10)
  NEWLINE
  IDENT(x)
  +
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
  =
  NEWLINE
  INDENT
  LET
  IDENT(x)
  =
  INT(10)
  NEWLINE
  IDENT(x)
  +
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
  IDENT(mut)
  IDENT(x)
  =
  INT(0)
  NEWLINE
  WHILE
  IDENT(x)
  <
  INT(10)
  :
  NEWLINE
  INDENT
  IDENT(x)
  =
  IDENT(x)
  +
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
  =
  NEWLINE
  INDENT
  LET
  IDENT(x)
  =
  INT(10)
  ;
  IDENT(x)
  +
  INT(5)
  NEWLINE
  IDENT(x)
  +
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
  =
  NEWLINE
  INDENT
  LET
  IDENT(c)
  =
  INT(0)
  NEWLINE
  INDENT
  IDENT(a)
  +
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
  :
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
  =
  NEWLINE
  INDENT
  IDENT(a)
  +
  INT(5)
  NEWLINE
  DEDENT
  IDENT(print_int)
  (
  IDENT(add)
  INT(10)
  )
  NEWLINE
  END
  NEWLINE
  EOF

String escape sequences:
  $ cat >test_esc.src <<'EOF'
  > let s = "hello\nworld"
  > let t = "tab\there"
  > let u = "quot\"here"
  > let v = "back\\slash"
  > let w = "\x41\x42"
  > let e = ""
  > EOF
  $ dune exec sylic lex test_esc.src
  LET
  IDENT(s)
  =
  STRING(hello
  world)
  NEWLINE
  LET
  IDENT(t)
  =
  STRING(tab	here)
  NEWLINE
  LET
  IDENT(u)
  =
  STRING(quot"here)
  NEWLINE
  LET
  IDENT(v)
  =
  STRING(back\slash)
  NEWLINE
  LET
  IDENT(w)
  =
  STRING(AB)
  NEWLINE
  LET
  IDENT(e)
  =
  STRING()
  NEWLINE
  EOF


type variant
  $ cat >test_variant.sy <<'EOF'
  > type option = None | Some of int64
  > EOF
  $ dune exec sylic lex test_variant.sy
  TYPE
  IDENT(option)
  =
  UIDENT(None)
  |
  UIDENT(Some)
  OF
  INT64
  NEWLINE
  EOF


pattern match
  $ cat >test_pattern.sy <<'EOF'
  > let m =
  >   match x with
  >     None -> 2
  >     Some _ -> 3
  > EOF
  $ dune exec sylic lex test_pattern.sy
  LET
  IDENT(m)
  =
  NEWLINE
  INDENT
  MATCH
  IDENT(x)
  WITH
  NEWLINE
  INDENT
  UIDENT(None)
  ->
  INT(2)
  NEWLINE
  UIDENT(Some)
  IDENT(_)
  ->
  INT(3)
  NEWLINE
  DEDENT
  DEDENT
  EOF

pattern match
  $ cat >test_pattern.sy <<'EOF'
  > let m =
  >   match x with None -> 2 | Some -> 30
  > EOF
  $ dune exec sylic lex test_pattern.sy
  LET
  IDENT(m)
  =
  NEWLINE
  INDENT
  MATCH
  IDENT(x)
  WITH
  UIDENT(None)
  ->
  INT(2)
  |
  UIDENT(Some)
  ->
  INT(30)
  NEWLINE
  DEDENT
  EOF
