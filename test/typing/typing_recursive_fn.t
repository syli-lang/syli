Typing recursive functions in Syli
  $ cat >test_file.sy <<EOF
  > let rec factorial n =
  >   if n == 0 then
  >     1
  >   else
  >     n * factorial (n - 1)
  > end
  > EOF
  $ cat test_file.sy
  let rec factorial n =
    if n == 0 then
      1
    else
      n * factorial (n - 1)
  end
  $ dune exec sylic typing test_file.sy
  Typed test_file.sy successfully: module Test_file with 1 top-level typed items
  Type Environment:
  {
    factorial : (int64) -> int64
  }
