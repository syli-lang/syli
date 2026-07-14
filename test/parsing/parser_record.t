
  $ cat >parse0.src <<EOF
  > fn add () =
  >  let record = { name = "test"; value = 5 }
  >  let n = record.value
  >  record.value = 10
  >  print_int(5)
  > end
  > EOF
  $ cat parse0.src
  fn add () =
   let record = { name = "test"; value = 5 }
   let n = record.value
   record.value = 10
   print_int(5)
  end

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

  $ cat >parse0.src <<EOF
  > fn add a =
  >   let record = { 
  >        name = "test"; value = 5 
  >   }
  >   let n = record.value
  > end
  > let _ = print_int (add 10)
  > EOF
  $ cat parse0.src
  fn add a =
    let record = { 
         name = "test"; value = 5 
    }
    let n = record.value
  end
  let _ = print_int (add 10)

  $ dune exec sylic parse parse0.src
  Parsed parse0.src
  fn add = lambda(a) {
    {
      let record = { name = "test"; value = 5 };
      let n = record.value
    }
  }
  let _ = print_int(add(10))


  $ cat >parse0.src <<EOF
  > fn add a =
  >   let record = { 
  >        name = "test"; value = 5 
  >   }
  >   let n = record.value
  > end
  > let _ = print_int (add 10)
  > EOF
  $ dune exec sylic parse parse0.src
  Parsed parse0.src
  fn add = lambda(a) {
    {
      let record = { name = "test"; value = 5 };
      let n = record.value
    }
  }
  let _ = print_int(add(10))


  $ cat >parse0.src <<EOF
  > fn add a =
  >   let record = { 
  >        name = "test"; value = 5 
  >     }
  >   let n = record.value
  > end
  > let _ = print_int (add 10)
  > EOF
  $ dune exec sylic parse parse0.src
  Parsed parse0.src
  fn add = lambda(a) {
    {
      let record = { name = "test"; value = 5 };
      let n = record.value
    }
  }
  let _ = print_int(add(10))

  $ cat >parse0.src <<EOF
  > fn add a =
  >   let record = 
  >   { 
  >        name = "test"; value = 5 
  >   }
  >   let n = record.value
  > end
  > let _ = print_int (add 10)
  > EOF
  $ dune exec sylic parse parse0.src
  Parsed parse0.src
  fn add = lambda(a) {
    {
      let record = { name = "test"; value = 5 };
      let n = record.value
    }
  }
  let _ = print_int(add(10))
