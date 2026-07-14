Closure lowering tests — fn_ptr generation for closures

Simple closure with one captured variable:
  $ cat >test_simple.sy <<EOF
  > let apply_twice f x = f (f x)
  > let double_x x = x + x
  > let result = apply_twice double_x 10
  > EOF
  $ dune exec sylic -- cir_mono test_simple.sy
  module Test_simple :
  globals:
  global public syliTest_simple.result : i64 = null init=__init_global.syliTest_simple.result
  
  
  functions:
  public fn __init.Test_simple() -> void:
    entry: bb0
  
    bb0:
      %__init_tmp_0:i64 = #call_direct __init_global.syliTest_simple.result ()
      store_global syliTest_simple.result = %__init_tmp_0:i64
      return
  end
  
  private fn __init_global.syliTest_simple.result() -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:(i64 -> i64) = #make_closure {syliTest_simple.double_x} () ()
      %Sy_var1:i64 = #call_direct syliTest_simple.apply_twice__fn_i64_i64__i64_ret_i64 (%Sy_var0:(i64 -> i64), 10:i64)
      return %Sy_var1:i64
  end
  
  public fn syliTest_simple.apply_twice__fn_i64_i64__i64_ret_i64(%f:(i64 -> i64), %x:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = #call_apply {%f:(i64 -> i64)}  (%x:i64)
      %Sy_var1:i64 = #call_apply {%f:(i64 -> i64)}  (%Sy_var0:i64)
      return %Sy_var1:i64
  end
  
  public fn syliTest_simple.double_x__i64_ret_i64(%x:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 + %x:i64
      return %Sy_var0:i64
  end
  
  end

Closure with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > let add x y = x + y
  > let apply f x y = f x y
  > let result = apply add 3 4
  > EOF
  $ dune exec sylic -- cir_mono test_multi.sy
  module Test_multi :
  globals:
  global public syliTest_multi.result : i64 = null init=__init_global.syliTest_multi.result
  
  
  functions:
  public fn __init.Test_multi() -> void:
    entry: bb0
  
    bb0:
      %__init_tmp_0:i64 = #call_direct __init_global.syliTest_multi.result ()
      store_global syliTest_multi.result = %__init_tmp_0:i64
      return
  end
  
  private fn __init_global.syliTest_multi.result() -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:(i64, i64 -> i64) = #make_closure {syliTest_multi.add} () ()
      %Sy_var1:i64 = #call_direct syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64 (%Sy_var0:(i64, i64 -> i64), 3:i64, 4:i64)
      return %Sy_var1:i64
  end
  
  public fn syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64(%f:(i64, i64 -> i64), %x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = #call_apply {%f:(i64, i64 -> i64)}  (%x:i64, %y:i64)
      return %Sy_var0:i64
  end
  
  public fn syliTest_multi.add__i64__i64_ret_i64(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 + %y:i64
      return %Sy_var0:i64
  end
  
  end

No closure (no fn_ptr generated):
  $ cat >test_no_closure.sy <<EOF
  > let x = 42
  > let y = x + 1
  > EOF
  $ dune exec sylic -- cir_mono test_no_closure.sy
  module Test_no_closure :
  globals:
  global public syliTest_no_closure.x : i64 = 42 init=__init_global.syliTest_no_closure.x
  global public syliTest_no_closure.y : i64 = null init=__init_global.syliTest_no_closure.y
  
  
  functions:
  public fn __init.Test_no_closure() -> void:
    entry: bb0
  
    bb0:
      %__init_tmp_0:i64 = #call_direct __init_global.syliTest_no_closure.x ()
      store_global syliTest_no_closure.x = %__init_tmp_0:i64
      %__init_tmp_1:i64 = #call_direct __init_global.syliTest_no_closure.y ()
      store_global syliTest_no_closure.y = %__init_tmp_1:i64
      return
  end
  
  private fn __init_global.syliTest_no_closure.y() -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %syliTest_no_closure.x:i64 + 1:i64
      return %Sy_var0:i64
  end
  
  private fn __init_global.syliTest_no_closure.x() -> i64:
    entry: bb0
  
    bb0:
  
      return 42:i64
  end
  
  end
