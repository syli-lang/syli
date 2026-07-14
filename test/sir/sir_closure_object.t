Closure-to-object lowering tests — make_closure/partial_apply transformed to object_create

Simple closure with one captured variable:
  $ cat >test_simple.sy <<EOF
  > let apply_twice f x = f (f x)
  > let double_x x = x + x
  > let result = apply_twice double_x 10
  > EOF
  $ dune exec sylic -- oir test_simple.sy
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
      gc_cycle
      %Sy_var0:*void = object_create{size=1:i32 record{fields=1 tag=0 [fn_ptr]}}
      
      %Sy_accum_fn_0:fn_ptr = addr_fn(__make_closure_accum.syliTest_simple.double_x.57_ret_i64)
      obj_set(%Sy_var0:*void, 0:i32, %Sy_accum_fn_0:fn_ptr):fn_ptr
      
      %Sy_var1:i64 = #call_direct syliTest_simple.apply_twice__fn_i64_i64__i64_ret_i64 (%Sy_var0:*void, 10:i64)
      rc_decr(%Sy_var0:*void)
      rc_check_release(%Sy_var0:*void)
      return %Sy_var1:i64
  end
  
  public fn syliTest_simple.apply_twice__fn_i64_i64__i64_ret_i64(%f:*void, %x:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_accum_ptr_1:fn_ptr = obj_get(%f:*void, 0:i32):fn_ptr
      %Sy_var0:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_1:fn_ptr)  (%x:i64, %f:*void, 0:i64)
      
      %Sy_accum_ptr_2:fn_ptr = obj_get(%f:*void, 0:i32):fn_ptr
      %Sy_var1:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_2:fn_ptr)  (%Sy_var0:i64, %f:*void, 0:i64)
      
      return %Sy_var1:i64
  end
  
  public fn syliTest_simple.double_x__i64_ret_i64(%x:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 + %x:i64
      return %Sy_var0:i64
  end
  
  private fn __make_closure_accum.syliTest_simple.double_x.57_ret_i64(%Sy_x0:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_rst:i64 = #call_direct __wrapper.syliTest_simple.double_x.i64_ret_i64 (%Sy_x0:i64)
      return %Sy_rst:i64
  end
  
  private fn __wrapper.syliTest_simple.double_x.i64_ret_i64(%Sy_x0:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_s0:i64 = cast(%Sy_x0:i64 as i64)
      %Sy_rst:i64 = #call_direct syliTest_simple.double_x__i64_ret_i64 (%Sy_s0:i64)
      return %Sy_rst:i64
  end
  
  end


Closure with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > let add x y = x + y
  > let apply f x y = f x y
  > let result = apply add 3 4
  > EOF
  $ dune exec sylic -- oir test_multi.sy
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
      gc_cycle
      %Sy_var0:*void = object_create{size=1:i32 record{fields=1 tag=0 [fn_ptr]}}
      
      %Sy_accum_fn_0:fn_ptr = addr_fn(__make_closure_accum.syliTest_multi.add.62_ret_i64)
      obj_set(%Sy_var0:*void, 0:i32, %Sy_accum_fn_0:fn_ptr):fn_ptr
      
      %Sy_var1:i64 = #call_direct syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64 (%Sy_var0:*void, 3:i64, 4:i64)
      rc_decr(%Sy_var0:*void)
      rc_check_release(%Sy_var0:*void)
      return %Sy_var1:i64
  end
  
  public fn syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64(%f:*void, %x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_accum_ptr_1:fn_ptr = obj_get(%f:*void, 0:i32):fn_ptr
      %Sy_var0:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_1:fn_ptr)  (%x:i64, %y:i64, %f:*void, 0:i64)
      
      return %Sy_var0:i64
  end
  
  public fn syliTest_multi.add__i64__i64_ret_i64(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 + %y:i64
      return %Sy_var0:i64
  end
  
  private fn __make_closure_accum.syliTest_multi.add.62_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_rst:i64 = #call_direct __wrapper.syliTest_multi.add.i64_i64_ret_i64 (%Sy_x0:i64, %Sy_x1:i64)
      return %Sy_rst:i64
  end
  
  private fn __wrapper.syliTest_multi.add.i64_i64_ret_i64(%Sy_x0:i64, %Sy_x1:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_s0:i64 = cast(%Sy_x0:i64 as i64)
      %Sy_s1:i64 = cast(%Sy_x1:i64 as i64)
      %Sy_rst:i64 = #call_direct syliTest_multi.add__i64__i64_ret_i64 (%Sy_s0:i64, %Sy_s1:i64)
      return %Sy_rst:i64
  end
  
  end


Closure with multipble chains of captured variables:
  $ cat >test_multi.sy <<EOF
  > let add x y z = x + y + z
  > let apply () =
  >   let add1 = add 1
  >   let add1and2 = add1 2
  >   let result = add1and2 3
  > EOF
  $ dune exec sylic -- oir test_multi.sy
  module Test_multi :
  functions:
  public fn __init.Test_multi() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_multi.apply() -> i64:
    entry: bb0
  
    bb0:
      gc_cycle
      %Sy_var0:*void = object_create{size=2:i32 record{fields=2 tag=0 [fn_ptr; i64]}}
      
      %Sy_accum_fn_0:fn_ptr = addr_fn(__make_closure_accum.syliTest_multi.add.41_ret_i64)
      obj_set(%Sy_var0:*void, 0:i32, %Sy_accum_fn_0:fn_ptr):fn_ptr
      obj_set(%Sy_var0:*void, 1:i32, 1:i64):i64
      
      gc_cycle
      %Sy_var1:*void = object_create{size=3:i32 record{fields=3 tag=0 [fn_ptr; *void; i64]}}
      
      %Sy_accum_fn_1:fn_ptr = addr_fn(__partial_closure_accum.clos1_arg1_ret_i64)
      obj_set(%Sy_var1:*void, 0:i32, %Sy_accum_fn_1:fn_ptr):fn_ptr
      obj_set(%Sy_var1:*void, 1:i32, %Sy_var0:*void):*void
      rc_decr(%Sy_var0:*void)
      rc_check_release(%Sy_var0:*void)
      obj_set(%Sy_var1:*void, 2:i32, 2:i64):i64
      
      %Sy_accum_ptr_2:fn_ptr = obj_get(%Sy_var1:*void, 0:i32):fn_ptr
      %Sy_var2:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_2:fn_ptr)  (3:i64, %Sy_var1:*void, 0:i64)
      rc_decr(%Sy_var1:*void)
      rc_check_release(%Sy_var1:*void)
      
      return %Sy_var2:i64
  end
  
  public fn syliTest_multi.add__i64__i64__i64_ret_i64(%x:i64, %y:i64, %z:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 + %y:i64
      %Sy_var1:i64 = %Sy_var0:i64 + %z:i64
      return %Sy_var1:i64
  end
  
  private fn __make_closure_accum.syliTest_multi.add.41_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 1:i64):i64
      %Sy_rst:i64 = #call_direct __wrapper.syliTest_multi.add.i64_i64_i64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64, %Sy_x1:i64)
      return %Sy_rst:i64
  end
  
  private fn __partial_closure_accum.clos1_arg1_ret_i64(%Sy_x0:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_p_clos:*void = obj_get(%Sy_clos:*void, 1:i64):*void
      %Sy_p_accum:fn_ptr = obj_get(%Sy_p_clos:*void, 0:i64):fn_ptr
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 2:i64):i64
      %Sy_rst:i64 = #call_direct_fn_ptr(%Sy_p_accum:fn_ptr)  (%Sy_val0:i64, %Sy_x0:i64, %Sy_p_clos:*void, %Sy_dp_id:i64)
      return %Sy_rst:i64
  end
  
  private fn __wrapper.syliTest_multi.add.i64_i64_i64_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_x2:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_s0:i64 = cast(%Sy_x0:i64 as i64)
      %Sy_s1:i64 = cast(%Sy_x1:i64 as i64)
      %Sy_s2:i64 = cast(%Sy_x2:i64 as i64)
      %Sy_rst:i64 = #call_direct syliTest_multi.add__i64__i64__i64_ret_i64 (%Sy_s0:i64, %Sy_s1:i64, %Sy_s2:i64)
      return %Sy_rst:i64
  end
  
  end


Closure with multipble chains of captured variables:
  $ cat >test_multi.sy <<EOF
  > let add x y z = x + y + z
  > let apply () =
  >   let add1 = add 1
  >   let add1and2 = add1 2
  >   add1and2
  > EOF
  $ dune exec sylic -- oir test_multi.sy
  module Test_multi :
  functions:
  public fn __init.Test_multi() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_multi.apply() -> *void:
    entry: bb0
  
    bb0:
      gc_cycle
      %Sy_var0:*void = object_create{size=2:i32 record{fields=2 tag=0 [fn_ptr; i64]}}
      
      %Sy_accum_fn_0:fn_ptr = addr_fn(__make_closure_accum.syliTest_multi.add.43_ret_i64)
      obj_set(%Sy_var0:*void, 0:i32, %Sy_accum_fn_0:fn_ptr):fn_ptr
      obj_set(%Sy_var0:*void, 1:i32, 1:i64):i64
      
      gc_cycle
      %Sy_var1:*void = object_create{size=3:i32 record{fields=3 tag=0 [fn_ptr; *void; i64]}}
      
      %Sy_accum_fn_1:fn_ptr = addr_fn(__partial_closure_accum.clos1_arg1_ret_i64)
      obj_set(%Sy_var1:*void, 0:i32, %Sy_accum_fn_1:fn_ptr):fn_ptr
      obj_set(%Sy_var1:*void, 1:i32, %Sy_var0:*void):*void
      rc_decr(%Sy_var0:*void)
      rc_check_release(%Sy_var0:*void)
      obj_set(%Sy_var1:*void, 2:i32, 2:i64):i64
      
      return %Sy_var1:*void
  end
  
  public fn syliTest_multi.add__i64__i64__i64_ret_i64(%x:i64, %y:i64, %z:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 + %y:i64
      %Sy_var1:i64 = %Sy_var0:i64 + %z:i64
      return %Sy_var1:i64
  end
  
  private fn __make_closure_accum.syliTest_multi.add.43_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 1:i64):i64
      %Sy_rst:i64 = #call_direct __wrapper.syliTest_multi.add.i64_i64_i64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64, %Sy_x1:i64)
      return %Sy_rst:i64
  end
  
  private fn __partial_closure_accum.clos1_arg1_ret_i64(%Sy_x0:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_p_clos:*void = obj_get(%Sy_clos:*void, 1:i64):*void
      %Sy_p_accum:fn_ptr = obj_get(%Sy_p_clos:*void, 0:i64):fn_ptr
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 2:i64):i64
      %Sy_rst:i64 = #call_direct_fn_ptr(%Sy_p_accum:fn_ptr)  (%Sy_val0:i64, %Sy_x0:i64, %Sy_p_clos:*void, %Sy_dp_id:i64)
      return %Sy_rst:i64
  end
  
  private fn __wrapper.syliTest_multi.add.i64_i64_i64_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_x2:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_s0:i64 = cast(%Sy_x0:i64 as i64)
      %Sy_s1:i64 = cast(%Sy_x1:i64 as i64)
      %Sy_s2:i64 = cast(%Sy_x2:i64 as i64)
      %Sy_rst:i64 = #call_direct syliTest_multi.add__i64__i64__i64_ret_i64 (%Sy_s0:i64, %Sy_s1:i64, %Sy_s2:i64)
      return %Sy_rst:i64
  end
  
  end


Lambda with captured variable (env param):
  $ cat >test_env.sy <<EOF
  > let make_adder x = lambda y -> x + y
  > EOF
  $ dune exec sylic -- oir test_env.sy
  module Test_env :
  functions:
  public fn __init.Test_env() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  end


Chain with Make_closure then Partial_apply — fn_ptr stored at the terminal leaf:
  $ cat >test_chain.sy <<EOF
  > let apply f x = f x
  > let add x y z = x + y + z
  > fn main () =
  >   let add1 = add 1
  >   let add2 = add1 10
  >   let result = add2 100
  >   result
  > EOF
  $ dune exec sylic -- oir test_chain.sy
  module Test_chain :
  functions:
  public fn __init.Test_chain() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_chain.main() -> i64:
    entry: bb0
  
    bb0:
      gc_cycle
      %Sy_var0:*void = object_create{size=2:i32 record{fields=2 tag=0 [fn_ptr; i64]}}
      
      %Sy_accum_fn_0:fn_ptr = addr_fn(__make_closure_accum.syliTest_chain.add.66_ret_i64)
      obj_set(%Sy_var0:*void, 0:i32, %Sy_accum_fn_0:fn_ptr):fn_ptr
      obj_set(%Sy_var0:*void, 1:i32, 1:i64):i64
      
      gc_cycle
      %Sy_var1:*void = object_create{size=3:i32 record{fields=3 tag=0 [fn_ptr; *void; i64]}}
      
      %Sy_accum_fn_1:fn_ptr = addr_fn(__partial_closure_accum.clos1_arg1_ret_i64)
      obj_set(%Sy_var1:*void, 0:i32, %Sy_accum_fn_1:fn_ptr):fn_ptr
      obj_set(%Sy_var1:*void, 1:i32, %Sy_var0:*void):*void
      rc_decr(%Sy_var0:*void)
      rc_check_release(%Sy_var0:*void)
      obj_set(%Sy_var1:*void, 2:i32, 10:i64):i64
      
      %Sy_accum_ptr_2:fn_ptr = obj_get(%Sy_var1:*void, 0:i32):fn_ptr
      %Sy_var2:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_2:fn_ptr)  (100:i64, %Sy_var1:*void, 0:i64)
      rc_decr(%Sy_var1:*void)
      rc_check_release(%Sy_var1:*void)
      
      return %Sy_var2:i64
  end
  
  public fn syliTest_chain.add__i64__i64__i64_ret_i64(%x:i64, %y:i64, %z:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 + %y:i64
      %Sy_var1:i64 = %Sy_var0:i64 + %z:i64
      return %Sy_var1:i64
  end
  
  private fn __make_closure_accum.syliTest_chain.add.66_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 1:i64):i64
      %Sy_rst:i64 = #call_direct __wrapper.syliTest_chain.add.i64_i64_i64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64, %Sy_x1:i64)
      return %Sy_rst:i64
  end
  
  private fn __partial_closure_accum.clos1_arg1_ret_i64(%Sy_x0:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_p_clos:*void = obj_get(%Sy_clos:*void, 1:i64):*void
      %Sy_p_accum:fn_ptr = obj_get(%Sy_p_clos:*void, 0:i64):fn_ptr
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 2:i64):i64
      %Sy_rst:i64 = #call_direct_fn_ptr(%Sy_p_accum:fn_ptr)  (%Sy_val0:i64, %Sy_x0:i64, %Sy_p_clos:*void, %Sy_dp_id:i64)
      return %Sy_rst:i64
  end
  
  private fn __wrapper.syliTest_chain.add.i64_i64_i64_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_x2:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_s0:i64 = cast(%Sy_x0:i64 as i64)
      %Sy_s1:i64 = cast(%Sy_x1:i64 as i64)
      %Sy_s2:i64 = cast(%Sy_x2:i64 as i64)
      %Sy_rst:i64 = #call_direct syliTest_chain.add__i64__i64__i64_ret_i64 (%Sy_s0:i64, %Sy_s1:i64, %Sy_s2:i64)
      return %Sy_rst:i64
  end
  
  end
No closure (no object_create generated):
  $ cat >test_no_closure.sy <<EOF
  > let x = 42
  > let y = x + 1
  > EOF
  $ dune exec sylic -- oir test_no_closure.sy
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
