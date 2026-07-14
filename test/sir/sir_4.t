Closure as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > let apply f x y = f x y
  > let add x y = x
  > fn main () = 
  >   let result = apply add  3 4
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
      %Sy_var0:(i64, i64 -> i64) = #make_closure {syliTest_multi.add} () ()
      %Sy_var1:i64 = #call_direct syliTest_multi.apply (%Sy_var0:(i64, i64 -> i64), 3:i64, 4:i64)
      return %Sy_var1:i64
  end
  
  public fn syliTest_multi.add(%x:?56, %y:?58) -> ?56:
    entry: bb0
  
    bb0:
  
      return %x:?56
  end
  
  public fn syliTest_multi.apply(%f:(?48, ?50 -> ?54), %x:?48, %y:?50) -> ?54:
    entry: bb0
  
    bb0:
      %Sy_var0:?54 = #call_apply {%f:(?48, ?50 -> ?54)}  (%x:?48, %y:?50)
      return %Sy_var0:?54
  end
  
  end

Closure as an argument with partial polymorphic closure:
  $ cat >test_multi.sy <<EOF
  > let apply f x y = f x y
  > let add x y z = x
  > fn main () =
  >   let add1 = add 1
  >   let result = apply add1 3 4
  >   let result2 = apply add1 1.0 2.0
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
      %Sy_var0:(?88, ?89 -> i64) = #make_closure {syliTest_multi.add} () ( captured_args=[1:i64])
      %Sy_var1:(i64, i64 -> i64) = cast(%Sy_var0:(?88, ?89 -> i64) as (i64, i64 -> i64))
      %Sy_var2:i64 = #call_direct syliTest_multi.apply (%Sy_var1:(i64, i64 -> i64), 3:i64, 4:i64)
      %Sy_var3:(f64, f64 -> i64) = cast(%Sy_var0:(?88, ?89 -> i64) as (f64, f64 -> i64))
      %Sy_var4:i64 = #call_direct syliTest_multi.apply (%Sy_var3:(f64, f64 -> i64), 1.0f:f64, 2.0f:f64)
      return %Sy_var4:i64
  end
  
  public fn syliTest_multi.add(%x:?79, %y:?81, %z:?83) -> ?79:
    entry: bb0
  
    bb0:
  
      return %x:?79
  end
  
  public fn syliTest_multi.apply(%f:(?71, ?73 -> ?77), %x:?71, %y:?73) -> ?77:
    entry: bb0
  
    bb0:
      %Sy_var0:?77 = #call_apply {%f:(?71, ?73 -> ?77)}  (%x:?71, %y:?73)
      return %Sy_var0:?77
  end
  
  end

Closure as an argument with partial polymorphic closure:
  $ cat >test_multi.sy <<EOF
  > let apply f x y = f x y
  > let add x y z = x
  > fn main () =
  >   let add1 = add 1
  >   let result = apply add1 3 4
  >   let result2 = apply add1 1.0 2.0
  > EOF
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
      %Sy_var0:(?88, ?89 -> i64) = #make_closure {syliTest_multi.add} () ( captured_args=[1:i64])
      %Sy_var1:(i64, i64 -> i64) = cast(%Sy_var0:(?88, ?89 -> i64) as (i64, i64 -> i64))
      %Sy_var2:i64 = #call_direct syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64 (%Sy_var1:(i64, i64 -> i64), 3:i64, 4:i64)
      %Sy_var3:(f64, f64 -> i64) = cast(%Sy_var0:(?88, ?89 -> i64) as (f64, f64 -> i64))
      %Sy_var4:i64 = #call_direct syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64 (%Sy_var3:(f64, f64 -> i64), 1.0f:f64, 2.0f:f64)
      return %Sy_var4:i64
  end
  
  public fn syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64(%f:(f64, f64 -> i64), %x:f64, %y:f64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = #call_apply {%f:(f64, f64 -> i64)}  (%x:f64, %y:f64)
      return %Sy_var0:i64
  end
  
  public fn syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64(%f:(i64, i64 -> i64), %x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = #call_apply {%f:(i64, i64 -> i64)}  (%x:i64, %y:i64)
      return %Sy_var0:i64
  end
  
  public fn syliTest_multi.add__i64__i64__i64_ret_i64(%x:i64, %y:i64, %z:i64) -> i64:
    entry: bb0
  
    bb0:
  
      return %x:i64
  end
  
  public fn syliTest_multi.add__i64__f64__f64_ret_i64(%x:i64, %y:f64, %z:f64) -> i64:
    entry: bb0
  
    bb0:
  
      return %x:i64
  end
  
  end

Closure as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > let apply f x y = f x y
  > let add x y z = x
  > fn main () =
  >   let add1 = add 1
  >   let result = apply add1 3 4
  >   let result2 = apply add1 1.0 2.0
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
      %Sy_var0:(?88, ?89 -> i64) = #make_closure {syliTest_multi.add} () ( captured_args=[1:i64])
      %Sy_var1:(i64, i64 -> i64) = cast(%Sy_var0:(?88, ?89 -> i64) as (i64, i64 -> i64))
      %Sy_var2:i64 = #call_direct syliTest_multi.apply (%Sy_var1:(i64, i64 -> i64), 3:i64, 4:i64)
      %Sy_var3:(f64, f64 -> i64) = cast(%Sy_var0:(?88, ?89 -> i64) as (f64, f64 -> i64))
      %Sy_var4:i64 = #call_direct syliTest_multi.apply (%Sy_var3:(f64, f64 -> i64), 1.0f:f64, 2.0f:f64)
      return %Sy_var4:i64
  end
  
  public fn syliTest_multi.add(%x:?79, %y:?81, %z:?83) -> ?79:
    entry: bb0
  
    bb0:
  
      return %x:?79
  end
  
  public fn syliTest_multi.apply(%f:(?71, ?73 -> ?77), %x:?71, %y:?73) -> ?77:
    entry: bb0
  
    bb0:
      %Sy_var0:?77 = #call_apply {%f:(?71, ?73 -> ?77)}  (%x:?71, %y:?73)
      return %Sy_var0:?77
  end
  
  end

Closure as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > let apply f x y = f x y
  > let add x y z = x
  > fn main () =
  >   let add1 = add 1
  >   let result = apply add1 3 4
  >   let result2 = apply add1 1.0 2.0
  > EOF
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  let syliTest_multi.apply = fun (f, x, y) : 'a77 ->
      f(x : 'a71, y : 'a73) : 'a77
  
  let syliTest_multi.add = fun (x, y, z) : 'a79 ->
      x : 'a79
  
  let syliTest_multi.main = fun () : i64 ->
      {
        let syliTest_multi.main__add1 = syliTest_multi.add(1 : i64) : ('a88, 'a89) -> i64
        let syliTest_multi.main__result = syliTest_multi.apply(syliTest_multi.main__add1 : (i64, i64) -> i64, 3 : i64, 4 : i64) : i64
        let syliTest_multi.main__result2 = syliTest_multi.apply(syliTest_multi.main__add1 : (double, double) -> i64, 1.0 : double, 2.0 : double) : i64
      }
  
Closure as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > let apply f x y = f x y
  > let add x y z = x
  > fn main () =
  >   let add1 = add 1
  >   let result = apply add1 3 4
  >   let result2 = apply add1 1.0 2.0
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
      %Sy_var0:(?88, ?89 -> i64) = #make_closure {syliTest_multi.add} () ( captured_args=[1:i64])
      %Sy_var1:(i64, i64 -> i64) = cast(%Sy_var0:(?88, ?89 -> i64) as (i64, i64 -> i64))
      %Sy_var2:i64 = #call_direct syliTest_multi.apply (%Sy_var1:(i64, i64 -> i64), 3:i64, 4:i64)
      %Sy_var3:(f64, f64 -> i64) = cast(%Sy_var0:(?88, ?89 -> i64) as (f64, f64 -> i64))
      %Sy_var4:i64 = #call_direct syliTest_multi.apply (%Sy_var3:(f64, f64 -> i64), 1.0f:f64, 2.0f:f64)
      return %Sy_var4:i64
  end
  
  public fn syliTest_multi.add(%x:?79, %y:?81, %z:?83) -> ?79:
    entry: bb0
  
    bb0:
  
      return %x:?79
  end
  
  public fn syliTest_multi.apply(%f:(?71, ?73 -> ?77), %x:?71, %y:?73) -> ?77:
    entry: bb0
  
    bb0:
      %Sy_var0:?77 = #call_apply {%f:(?71, ?73 -> ?77)}  (%x:?71, %y:?73)
      return %Sy_var0:?77
  end
  
  end


Closure as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > let apply f x y = f x y
  > let add x y z = x
  > fn main () =
  >   let add1 = add 1
  >   let result = apply add1 3 4
  >   let result2 = apply add1 1.0 2.0
  > EOF
  $ dune exec sylic -- cir test_multi.sy
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
      %Sy_var0:(?88, ?89 -> i64) = #make_closure {syliTest_multi.add} () ( captured_args=[1:i64])
      %Sy_var1:(i64, i64 -> i64) = cast(%Sy_var0:(?88, ?89 -> i64) as (i64, i64 -> i64))
      %Sy_var2:i64 = #call_direct syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64 (%Sy_var1:(i64, i64 -> i64), 3:i64, 4:i64)
      %Sy_var3:(f64, f64 -> i64) = cast(%Sy_var0:(?88, ?89 -> i64) as (f64, f64 -> i64))
      %Sy_var4:i64 = #call_direct syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64 (%Sy_var3:(f64, f64 -> i64), 1.0f:f64, 2.0f:f64)
      return %Sy_var4:i64
  end
  
  public fn syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64(%f:(f64, f64 -> i64), %x:f64, %y:f64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = #call_apply {%f:(f64, f64 -> i64)}  (%x:f64, %y:f64)
      return %Sy_var0:i64
  end
  
  public fn syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64(%f:(i64, i64 -> i64), %x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = #call_apply {%f:(i64, i64 -> i64)}  (%x:i64, %y:i64)
      return %Sy_var0:i64
  end
  
  public fn syliTest_multi.add__i64__i64__i64_ret_i64(%x:i64, %y:i64, %z:i64) -> i64:
    entry: bb0
  
    bb0:
  
      return %x:i64
  end
  
  public fn syliTest_multi.add__i64__f64__f64_ret_i64(%x:i64, %y:f64, %z:f64) -> i64:
    entry: bb0
  
    bb0:
  
      return %x:i64
  end
  
  end
