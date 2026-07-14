Self describing signature parsing tests 
  $ cat >parse0.src <<EOF
  > signature:
  >   val add : int -> int
  > end
  > let x = 10
  > EOF
  $ cat parse0.src
  signature:
    val add : int -> int
  end
  let x = 10

  $ dune exec sylic parse parse0.src
  Parsed parse0.src
  signature:
    val add : int -> int
  end
  let x = 10

Signature parsing with external declarations
  $ cat >parse0.src <<EOF
  > signature:
  >   val add : int -> int
  >   extern print_int : int -> unit = "print_int"
  > end
  > let x = 10
  > EOF
  $ cat parse0.src
  signature:
    val add : int -> int
    extern print_int : int -> unit = "print_int"
  end
  let x = 10

  $ dune exec sylic parse parse0.src
  Parsed parse0.src
  signature:
    val add : int -> int
    extern print_int : int -> unit = "print_int"
  end
  let x = 10

