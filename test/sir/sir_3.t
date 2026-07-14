Overriding same name variable in the top-level scope:
  $ cat >test_shadow.sy <<EOF
  > let x = 5
  > let y = x + 1
  > let x = 10
  > let result = x + 1
  > EOF
  $ dune exec sylic -- cir_raw test_shadow.sy
  module Test_shadow :
  globals:
  global public syliTest_shadow.x#1 : i64 = 5 init=__init_global.syliTest_shadow.x#1
  global public syliTest_shadow.y : i64 = null init=__init_global.syliTest_shadow.y
  global public syliTest_shadow.x : i64 = 10 init=__init_global.syliTest_shadow.x
  global public syliTest_shadow.result : i64 = null init=__init_global.syliTest_shadow.result
  
  
  functions:
  public fn __init.Test_shadow() -> void:
    entry: bb0
  
    bb0:
      %__init_tmp_0:i64 = #call_direct __init_global.syliTest_shadow.x#1 ()
      store_global syliTest_shadow.x#1 = %__init_tmp_0:i64
      %__init_tmp_1:i64 = #call_direct __init_global.syliTest_shadow.y ()
      store_global syliTest_shadow.y = %__init_tmp_1:i64
      %__init_tmp_2:i64 = #call_direct __init_global.syliTest_shadow.x ()
      store_global syliTest_shadow.x = %__init_tmp_2:i64
      %__init_tmp_3:i64 = #call_direct __init_global.syliTest_shadow.result ()
      store_global syliTest_shadow.result = %__init_tmp_3:i64
      return
  end
  
  private fn __init_global.syliTest_shadow.result() -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %syliTest_shadow.x:i64 + 1:i64
      return %Sy_var0:i64
  end
  
  private fn __init_global.syliTest_shadow.x() -> i64:
    entry: bb0
  
    bb0:
  
      return 10:i64
  end
  
  private fn __init_global.syliTest_shadow.y() -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %syliTest_shadow.x#1:i64 + 1:i64
      return %Sy_var0:i64
  end
  
  private fn __init_global.syliTest_shadow.x#1() -> i64:
    entry: bb0
  
    bb0:
  
      return 5:i64
  end
  
  end


Overriding same name variable in a nested scope:
  $ cat >test_shadow_nested.sy <<EOF
  > let x = 5
  > let apply () =
  >   let x = 10
  >   let result = x + 1
  > EOF
  $ dune exec sylic -- cir_raw test_shadow_nested.sy
  module Test_shadow_nested :
  globals:
  global public syliTest_shadow_nested.x : i64 = 5 init=__init_global.syliTest_shadow_nested.x
  
  
  functions:
  public fn __init.Test_shadow_nested() -> void:
    entry: bb0
  
    bb0:
      %__init_tmp_0:i64 = #call_direct __init_global.syliTest_shadow_nested.x ()
      store_global syliTest_shadow_nested.x = %__init_tmp_0:i64
      return
  end
  
  public fn syliTest_shadow_nested.apply() -> i64:
    entry: bb0
  
    bb0:
      %syliTest_shadow_nested.apply__x:i64 = cast(10:i64 as i64)
      %Sy_var0:i64 = %syliTest_shadow_nested.apply__x:i64 + 1:i64
      return %Sy_var0:i64
  end
  
  private fn __init_global.syliTest_shadow_nested.x() -> i64:
    entry: bb0
  
    bb0:
  
      return 5:i64
  end
  
  end

Toplevel free variable capture:
  $ cat >test_toplevel_capture.sy <<EOF
  > let x = 5
  > let add_to_x y = x + y
  > let result = add_to_x 10
  > EOF
  $ dune exec sylic -- cir_raw test_toplevel_capture.sy
  module Test_toplevel_capture :
  globals:
  global public syliTest_toplevel_capture.x : i64 = 5 init=__init_global.syliTest_toplevel_capture.x
  global public syliTest_toplevel_capture.result : i64 = null init=__init_global.syliTest_toplevel_capture.result
  
  
  functions:
  public fn __init.Test_toplevel_capture() -> void:
    entry: bb0
  
    bb0:
      %__init_tmp_0:i64 = #call_direct __init_global.syliTest_toplevel_capture.x ()
      store_global syliTest_toplevel_capture.x = %__init_tmp_0:i64
      %__init_tmp_1:i64 = #call_direct __init_global.syliTest_toplevel_capture.result ()
      store_global syliTest_toplevel_capture.result = %__init_tmp_1:i64
      return
  end
  
  private fn __init_global.syliTest_toplevel_capture.result() -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = #call_direct syliTest_toplevel_capture.add_to_x (10:i64)
      return %Sy_var0:i64
  end
  
  public fn syliTest_toplevel_capture.add_to_x(%y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %syliTest_toplevel_capture.x:i64 + %y:i64
      return %Sy_var0:i64
  end
  
  private fn __init_global.syliTest_toplevel_capture.x() -> i64:
    entry: bb0
  
    bb0:
  
      return 5:i64
  end
  
  end

Simple nested function without captured variables:
  $ cat >test_nested_simple.sy <<EOF
  > let y = 10
  > let outer x =
  >   let inner y = y + x + 1
  >   inner 2
  > EOF
  $ dune exec sylic -- cir test_nested_simple.sy
  module Test_nested_simple :
  globals:
  global public syliTest_nested_simple.y : i64 = 10 init=__init_global.syliTest_nested_simple.y
  
  
  functions:
  public fn __init.Test_nested_simple() -> void:
    entry: bb0
  
    bb0:
      %__init_tmp_0:i64 = #call_direct __init_global.syliTest_nested_simple.y ()
      store_global syliTest_nested_simple.y = %__init_tmp_0:i64
      return
  end
  
  public fn syliTest_nested_simple.outer(%x:i64) -> i64:
    entry: bb0
  
    bb0:
      %syliTest_nested_simple.outer__inner:(i64 -> i64) = #make_closure {syliTest_nested_simple.outer__inner} (%x:i64) ()
      %Sy_var0:i64 = #call_apply {%syliTest_nested_simple.outer__inner:(i64 -> i64)}  (2:i64)
      return %Sy_var0:i64
  end
  
  private fn __init_global.syliTest_nested_simple.y() -> i64:
    entry: bb0
  
    bb0:
  
      return 10:i64
  end
  
  private fn syliTest_nested_simple.outer__inner(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %y:i64 + %x:i64
      %Sy_var1:i64 = %Sy_var0:i64 + 1:i64
      return %Sy_var1:i64
  end
  
  end

Closure with multipble chains of captured variables:
  $ cat >test_multi.sy <<EOF
  > let add x y z = x + y + z
  > let add1 = add 1
  > let add1and2 = add1 2
  > let result = add1and2 3
  > EOF
  $ dune exec sylic -- cir_raw test_multi.sy
  module Test_multi :
  globals:
  global public syliTest_multi.add1 : (i64, i64 -> i64) = null init=__init_global.syliTest_multi.add1
  global public syliTest_multi.add1and2 : (i64 -> i64) = null init=__init_global.syliTest_multi.add1and2
  global public syliTest_multi.result : i64 = null init=__init_global.syliTest_multi.result
  
  
  functions:
  public fn __init.Test_multi() -> void:
    entry: bb0
  
    bb0:
      %__init_tmp_0:(i64, i64 -> i64) = #call_direct __init_global.syliTest_multi.add1 ()
      store_global syliTest_multi.add1 = %__init_tmp_0:(i64, i64 -> i64)
      %__init_tmp_1:(i64 -> i64) = #call_direct __init_global.syliTest_multi.add1and2 ()
      store_global syliTest_multi.add1and2 = %__init_tmp_1:(i64 -> i64)
      %__init_tmp_2:i64 = #call_direct __init_global.syliTest_multi.result ()
      store_global syliTest_multi.result = %__init_tmp_2:i64
      return
  end
  
  private fn __init_global.syliTest_multi.result() -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = #call_apply {%syliTest_multi.add1and2:(i64 -> i64)}  (3:i64)
      return %Sy_var0:i64
  end
  
  private fn __init_global.syliTest_multi.add1and2() -> (i64 -> i64):
    entry: bb0
  
    bb0:
      %Sy_var0:(i64 -> i64) = #partial_apply {%syliTest_multi.add1:(i64, i64 -> i64)} (2:i64)
      return %Sy_var0:(i64 -> i64)
  end
  
  private fn __init_global.syliTest_multi.add1() -> (i64, i64 -> i64):
    entry: bb0
  
    bb0:
      %Sy_var0:(i64, i64 -> i64) = #make_closure {syliTest_multi.add} () ( captured_args=[1:i64])
      return %Sy_var0:(i64, i64 -> i64)
  end
  
  public fn syliTest_multi.add(%x:?49, %y:?49, %z:?49) -> ?49:
    entry: bb0
  
    bb0:
      %Sy_var0:?49 = %x:?49 + %y:?49
      %Sy_var1:?49 = %Sy_var0:?49 + %z:?49
      return %Sy_var1:?49
  end
  
  end

TODO: main function should be lowered correctly,
No variable type should be inside main function.

Nested polymorphic function passed as an argument:
  $ cat >test_multi.sy <<EOF
  > let apply f x y = f x y
  > fn main () =
  >   let add a b = a + b
  >   let result = apply add 3 4
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
      %syliTest_multi.main__add:(?63, ?63 -> ?63) = #make_closure {syliTest_multi.main__add} () ()
      %Sy_var0:(i64, i64 -> i64) = cast(%syliTest_multi.main__add:(?63, ?63 -> ?63) as (i64, i64 -> i64))
      %Sy_var1:i64 = #call_direct syliTest_multi.apply (%Sy_var0:(i64, i64 -> i64), 3:i64, 4:i64)
      return %Sy_var1:i64
  end
  
  public fn syliTest_multi.apply(%f:(?52, ?54 -> ?58), %x:?52, %y:?54) -> ?58:
    entry: bb0
  
    bb0:
      %Sy_var0:?58 = #call_apply {%f:(?52, ?54 -> ?58)}  (%x:?52, %y:?54)
      return %Sy_var0:?58
  end
  
  private fn syliTest_multi.main__add(%a:?63, %b:?63) -> ?63:
    entry: bb0
  
    bb0:
      %Sy_var0:?63 = %a:?63 + %b:?63
      return %Sy_var0:?63
  end
  
  end

Applying partially applied function:
  $ cat >test_multi.sy <<EOF
  > let add x y = x + y
  > fn main () =
  >   let result = (add 1) 2
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
      %Sy_var0:(i64 -> i64) = #make_closure {syliTest_multi.add} () ( captured_args=[1:i64])
      %Sy_var1:i64 = #call_apply {%Sy_var0:(i64 -> i64)}  (2:i64)
      return %Sy_var1:i64
  end
  
  public fn syliTest_multi.add(%x:?33, %y:?33) -> ?33:
    entry: bb0
  
    bb0:
      %Sy_var0:?33 = %x:?33 + %y:?33
      return %Sy_var0:?33
  end
  
  end
