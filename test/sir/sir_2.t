A function with let bindings:
  $ cat >test_let.sy <<EOF
  > fn let_bingings () =
  >   let x = 10
  >   let y = x + 32
  > EOF
  $ dune exec sylic -- cir_raw test_let.sy
  module Test_let :
  functions:
  public fn __init.Test_let() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_let.let_bingings() -> i64:
    entry: bb0
  
    bb0:
      %syliTest_let.let_bingings__x:i64 = cast(10:i64 as i64)
      %Sy_var0:i64 = %syliTest_let.let_bingings__x:i64 + 32:i64
      return %Sy_var0:i64
  end
  
  end


Simple Partial apply (ir_fp — after generate_functions, before monomorphize):
  $ cat >test_partial.sy <<EOF
  > fn add x y = x + y
  > let m = add 5
  > EOF
  $ dune exec sylic -- cir_raw test_partial.sy
  module Test_partial :
  globals:
  global public syliTest_partial.m : (i64 -> i64) = null init=__init_global.syliTest_partial.m
  
  
  functions:
  public fn __init.Test_partial() -> void:
    entry: bb0
  
    bb0:
      %__init_tmp_0:(i64 -> i64) = #call_direct __init_global.syliTest_partial.m ()
      store_global syliTest_partial.m = %__init_tmp_0:(i64 -> i64)
      return
  end
  
  private fn __init_global.syliTest_partial.m() -> (i64 -> i64):
    entry: bb0
  
    bb0:
      %Sy_var0:(i64 -> i64) = #make_closure {syliTest_partial.add} () ( captured_args=[5:i64])
      return %Sy_var0:(i64 -> i64)
  end
  
  public fn syliTest_partial.add(%x:?25, %y:?25) -> ?25:
    entry: bb0
  
    bb0:
      %Sy_var0:?25 = %x:?25 + %y:?25
      return %Sy_var0:?25
  end
  
  end


Simple Partial apply (ir):
  $ cat >test_partial.sy <<EOF
  > fn add x y = x + y
  > let m = add 5
  > EOF
  $ dune exec sylic -- cir_raw test_partial.sy
  module Test_partial :
  globals:
  global public syliTest_partial.m : (i64 -> i64) = null init=__init_global.syliTest_partial.m
  
  
  functions:
  public fn __init.Test_partial() -> void:
    entry: bb0
  
    bb0:
      %__init_tmp_0:(i64 -> i64) = #call_direct __init_global.syliTest_partial.m ()
      store_global syliTest_partial.m = %__init_tmp_0:(i64 -> i64)
      return
  end
  
  private fn __init_global.syliTest_partial.m() -> (i64 -> i64):
    entry: bb0
  
    bb0:
      %Sy_var0:(i64 -> i64) = #make_closure {syliTest_partial.add} () ( captured_args=[5:i64])
      return %Sy_var0:(i64 -> i64)
  end
  
  public fn syliTest_partial.add(%x:?25, %y:?25) -> ?25:
    entry: bb0
  
    bb0:
      %Sy_var0:?25 = %x:?25 + %y:?25
      return %Sy_var0:?25
  end
  
  end


Simple Partial apply (ir_mono):
  $ cat >test_partial.sy <<EOF
  > fn add x y = x + y
  > let m = add 5
  > EOF
  $ dune exec sylic -- cir_mono test_partial.sy | grep "#make_closure"
      %Sy_var0:(i64 -> i64) = #make_closure {syliTest_partial.add} () ( captured_args=[5:i64])


Simple Partial apply (ir_raw):
  $ cat >test_partial.sy <<EOF
  > fn add x y = x + y
  > let m = add 5
  > EOF
  $ dune exec sylic -- cir_raw test_partial.sy
  module Test_partial :
  globals:
  global public syliTest_partial.m : (i64 -> i64) = null init=__init_global.syliTest_partial.m
  
  
  functions:
  public fn __init.Test_partial() -> void:
    entry: bb0
  
    bb0:
      %__init_tmp_0:(i64 -> i64) = #call_direct __init_global.syliTest_partial.m ()
      store_global syliTest_partial.m = %__init_tmp_0:(i64 -> i64)
      return
  end
  
  private fn __init_global.syliTest_partial.m() -> (i64 -> i64):
    entry: bb0
  
    bb0:
      %Sy_var0:(i64 -> i64) = #make_closure {syliTest_partial.add} () ( captured_args=[5:i64])
      return %Sy_var0:(i64 -> i64)
  end
  
  public fn syliTest_partial.add(%x:?25, %y:?25) -> ?25:
    entry: bb0
  
    bb0:
      %Sy_var0:?25 = %x:?25 + %y:?25
      return %Sy_var0:?25
  end
  
  end


Partial apply from a lambda with captured local value:
  $ cat >_tmp_partial2.sy <<EOF
  > fn make_partial () = (lambda x y -> x + y) 5
  > EOF
  $ dune exec sylic -- cir_raw _tmp_partial2.sy
  module _tmp_partial2 :
  functions:
  public fn __init._tmp_partial2() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syli_tmp_partial2.make_partial() -> (i64 -> i64):
    entry: bb0
  
    bb0:
      %__lambda_14:(i64, i64 -> i64) = #make_closure {__lambda_14} () ()
      %Sy_var0:(i64 -> i64) = #partial_apply {%__lambda_14:(i64, i64 -> i64)} (5:i64)
      return %Sy_var0:(i64 -> i64)
  end
  
  public fn __lambda_14(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 + %y:i64
      return %Sy_var0:i64
  end
  
  end
