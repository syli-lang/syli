Closure fan-out through if-then-else with dispatch:
  $ cat >test_fanout.sy <<EOF
  > let add x y = x + y
  > let sub x y = x - y
  > fn main () =
  >   let add1 = add 1
  >   let sub1 = sub 1
  >   let f = if true then add1 else sub1
  >   f 2
  > EOF
  $ dune exec sylic -- cir test_fanout.sy 2>&1
  module Test_fanout :
  functions:
  public fn __init.Test_fanout() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_fanout.main() -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:(i64 -> i64) = #make_closure {syliTest_fanout.add} () ( captured_args=[1:i64])
      %Sy_var1:(i64 -> i64) = #make_closure {syliTest_fanout.sub} () ( captured_args=[1:i64])
      %Sy_var2:bool = cast(true:bool as bool)
      cond_br %Sy_var2:bool, bb1, bb2
  
    bb2:
      %Sy_var3:(i64 -> i64) = move(%Sy_var1:(i64 -> i64))
      goto bb3
  
    bb1:
      %Sy_var3:(i64 -> i64) = move(%Sy_var0:(i64 -> i64))
      goto bb3
  
    bb3:
      %Sy_var4:i64 = #call_apply {%Sy_var3:(i64 -> i64)}  (2:i64)
      return %Sy_var4:i64
  end
  
  public fn syliTest_fanout.sub__i64__i64_ret_i64(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 - %y:i64
      return %Sy_var0:i64
  end
  
  public fn syliTest_fanout.add__i64__i64_ret_i64(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 + %y:i64
      return %Sy_var0:i64
  end
  
  end
