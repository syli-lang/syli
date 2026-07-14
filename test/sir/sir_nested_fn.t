Nested functions:
  $ cat >test_multi.sy <<EOF
  > fn main () =
  >   let apply f x y = f x y
  >   let add x y z = x + z
  >   let add1 = add 1.0
  >   let result = apply add1 3 4.0
  >   let result2 = apply add1 1.0 2.0
  >   0
  > EOF
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  let syliTest_multi.main = fun () : i64 ->
      {
        let syliTest_multi.main__apply = fun (f, x, y) : 'a83 ->
            f(x : 'a77, y : 'a79) : 'a83
        let syliTest_multi.main__add = fun (x, y, z) : 'a89 ->
            (x : 'a89 + z : 'a89) : 'a89
        let syliTest_multi.main__add1 = syliTest_multi.main__add(1.0 : double) : ('a92, double) -> double
        let syliTest_multi.main__result = syliTest_multi.main__apply(syliTest_multi.main__add1 : (i64, double) -> double, 3 : i64, 4.0 : double) : double
        let syliTest_multi.main__result2 = syliTest_multi.main__apply(syliTest_multi.main__add1 : (double, double) -> double, 1.0 : double, 2.0 : double) : double
        0 : i64
      }
  

Nested functions:
  $ cat >test_multi.sy <<EOF
  > fn main () =
  >   let apply f x y = f x y
  >   let add x y z = x + z
  >   let add1 = add 1.0
  >   let result = apply add1 3 4.0
  >   let result2 = apply add1 1.0 2.0
  >   0
  > EOF
  $ dune exec sylic -- cir_raw test_multi.sy
  module Test_multi :
  functions:
  public fn __init.Test_multi() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_multi.main() -> i64:
    entry: bb0
  
    bb0:
      %syliTest_multi.main__apply:((?77, ?79 -> ?83), ?77, ?79 -> ?83) = #make_closure {syliTest_multi.main__apply} () ()
      %syliTest_multi.main__add:(?89, ?87, ?89 -> ?89) = #make_closure {syliTest_multi.main__add} () ()
      %Sy_var0:(?92, f64 -> f64) = #partial_apply {%syliTest_multi.main__add:(?89, ?87, ?89 -> ?89)} (1.0f:f64)
      %Sy_var1:(i64, f64 -> f64) = cast(%Sy_var0:(?92, f64 -> f64) as (i64, f64 -> f64))
      %Sy_var2:f64 = #call_apply {%syliTest_multi.main__apply:((?77, ?79 -> ?83), ?77, ?79 -> ?83) as ((i64, f64 -> f64), i64, f64 -> f64)}  (%Sy_var1:(i64, f64 -> f64), 3:i64, 4.0f:f64)
      %Sy_var3:(f64, f64 -> f64) = cast(%Sy_var0:(?92, f64 -> f64) as (f64, f64 -> f64))
      %Sy_var4:f64 = #call_apply {%syliTest_multi.main__apply:((?77, ?79 -> ?83), ?77, ?79 -> ?83) as ((f64, f64 -> f64), f64, f64 -> f64)}  (%Sy_var3:(f64, f64 -> f64), 1.0f:f64, 2.0f:f64)
      return 0:i64
  end
  
  private fn syliTest_multi.main__apply(%f:(?77, ?79 -> ?83), %x:?77, %y:?79) -> ?83:
    entry: bb0
  
    bb0:
      %Sy_var0:?83 = #call_apply {%f:(?77, ?79 -> ?83)}  (%x:?77, %y:?79)
      return %Sy_var0:?83
  end
  
  private fn syliTest_multi.main__add(%x:?89, %y:?87, %z:?89) -> ?89:
    entry: bb0
  
    bb0:
      %Sy_var0:?89 = %x:?89 + %z:?89
      return %Sy_var0:?89
  end
  
  end

  $ dune exec sylic -- cir_mono test_multi.sy
  module Test_multi :
  functions:
  public fn __init.Test_multi() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_multi.main() -> i64:
    entry: bb0
  
    bb0:
      %syliTest_multi.main__apply:((?77, ?79 -> ?83), ?77, ?79 -> ?83) = #make_closure {syliTest_multi.main__apply} () ()
      %syliTest_multi.main__add:(?89, ?87, ?89 -> ?89) = #make_closure {syliTest_multi.main__add} () ()
      %Sy_var0:(?92, f64 -> f64) = #partial_apply {%syliTest_multi.main__add:(?89, ?87, ?89 -> ?89)} (1.0f:f64)
      %Sy_var1:(i64, f64 -> f64) = cast(%Sy_var0:(?92, f64 -> f64) as (i64, f64 -> f64))
      %Sy_var2:f64 = #call_apply {%syliTest_multi.main__apply:((?77, ?79 -> ?83), ?77, ?79 -> ?83) as ((i64, f64 -> f64), i64, f64 -> f64)}  (%Sy_var1:(i64, f64 -> f64), 3:i64, 4.0f:f64)
      %Sy_var3:(f64, f64 -> f64) = cast(%Sy_var0:(?92, f64 -> f64) as (f64, f64 -> f64))
      %Sy_var4:f64 = #call_apply {%syliTest_multi.main__apply:((?77, ?79 -> ?83), ?77, ?79 -> ?83) as ((f64, f64 -> f64), f64, f64 -> f64)}  (%Sy_var3:(f64, f64 -> f64), 1.0f:f64, 2.0f:f64)
      return 0:i64
  end
  
  private fn syliTest_multi.main__add__f64__i64__f64_ret_f64(%x:f64, %y:i64, %z:f64) -> f64:
    entry: bb0
  
    bb0:
      %Sy_var0:f64 = %x:f64 + %z:f64
      return %Sy_var0:f64
  end
  
  private fn syliTest_multi.main__add__f64__f64__f64_ret_f64(%x:f64, %y:f64, %z:f64) -> f64:
    entry: bb0
  
    bb0:
      %Sy_var0:f64 = %x:f64 + %z:f64
      return %Sy_var0:f64
  end
  
  private fn syliTest_multi.main__apply__fn_i64_f64_f64__i64__f64_ret_f64(%f:(i64, f64 -> f64), %x:i64, %y:f64) -> f64:
    entry: bb0
  
    bb0:
      %Sy_var0:f64 = #call_apply {%f:(i64, f64 -> f64)}  (%x:i64, %y:f64)
      return %Sy_var0:f64
  end
  
  private fn syliTest_multi.main__apply__fn_f64_f64_f64__f64__f64_ret_f64(%f:(f64, f64 -> f64), %x:f64, %y:f64) -> f64:
    entry: bb0
  
    bb0:
      %Sy_var0:f64 = #call_apply {%f:(f64, f64 -> f64)}  (%x:f64, %y:f64)
      return %Sy_var0:f64
  end
  
  end
