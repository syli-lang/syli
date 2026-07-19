# Syli

[![CI](https://github.com/syli-lang/syli/actions/workflows/ci.yml/badge.svg)](https://github.com/syli-lang/syli/actions/workflows/ci.yml)

## Overview

Syli is a general-purpose programming language with a core functional language. The runtime is a refcount based system with tracing fallback for completeness to avoid supporting weak-references.

The goal of this language is to have low latency, high performance with more expressivity. The language is compiled into native code.

The closure concept is based on a closure graph that uses **Ball-Larus** algorithm which unlock polymorphism with monomorphization combined with modules and functions boundaries. This is the only exclusive thing of the language.

This language is not doing something totally new, it is trying to hold on giants, to borrow from languages that are mature and doing amazing things for years.

> [!CAUTION]
> The project is under development, it is not ready for production yet.

## Building

### System Requirements
- CMake 2.20+
- Clang 17.0+
- LLVM 17.0+

### Install Opam and Dune

Install Opam via [opam](https://opam.ocaml.org/doc/Install.html)

Create an empty switch
```sh
opam create switch syli-lang --empty
```

Install all deps and Dune
```sh
opam install . --deps-only
```

### Setup, build and run all test

Local setup of some env path for the development.
```sh
source setup.sh
```
Build the runtime
```
make -C runtime syliruntime
```
Build and run the tests
```sh
dune build
dune runtest
```

## Examples

### Fibonacci

```sy
signature:
  extern syli_print_i64 : int64 -> unit = "syli_print_i64"
end
let rec fib n =
  if n == 0 then
    0
  else if n == 1 then
    1
  else
    fib (n - 1) + fib (n - 2)
fn main () = syli_print_i64 (fib 10)
```

```sh
$ dune exec sylic -- build fib.sy && ./fib.exe
55
```

### Function composition

```sy
signature:
  extern syli_print_i64 : int64 -> unit = "syli_print_i64"
end
let add x y = x + y
let apply f x = f x
let compose f g x = f (g x)
fn main () =
    let r = compose (add 10) (add 20) 5
    syli_print_i64 r
```

```sh
$ dune exec sylic -- build compose.sy && ./compose.exe
35
```

## Roadmap

See [ROADMAP.md](ROADMAP.md)

## Contributions

See [CONTRIBUTING](CONTRIBUTING.md)

## License

Licensed under both

* Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or <http://www.apache.org/licenses/LICENSE-2.0>)
* MIT license ([LICENSE-MIT](LICENSE-MIT) or <http://opensource.org/licenses/MIT>)
