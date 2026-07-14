OIR with RC insertion

Record object with ref variable death:
  $ cat >test_rc1.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > type person = { name: int64; age: int64 }
  > fn main () =
  >     let record = { name = 10; age = 30 }
  >     syli_print_i64(record.age)
  > EOF
  $ dune exec sylic -- oir test_rc1.sy
  module Test_rc1 :
  ffi_external_functions:
  extern fn syli_print_i64(i64) -> void
  
  
  functions:
  public fn __init.Test_rc1() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_rc1.main() -> void:
    entry: bb0
  
    bb0:
      gc_cycle
      %Sy_var0:obj = object_create{size=2:i64 record{fields=2 tag=0 [i64; i64]}}
      
      obj_set(%Sy_var0:obj, 0:i64, 10:i64):i64
      obj_set(%Sy_var0:obj, 1:i64, 30:i64):i64
      %Sy_var1:i64 = obj_get(%Sy_var0:obj, 1:i64):i64
      rc_decr(%Sy_var0:obj)
      rc_check_release(%Sy_var0:obj)
      %Sy_var2:void = #call_direct syliTest_rc1.syli_print_i64 (%Sy_var1:i64)
      return
  end
  
  end

Multiple ref variables with independent lifetimes:
  $ cat >test_rc2.sy <<EOF
  > type box = { value: int64 }
  > fn main () =
  >     let a = { value = 1 }
  >     let b = { value = 2 }
  >     let r = a.value + b.value
  > EOF
  $ dune exec sylic -- oir test_rc2.sy
  module Test_rc2 :
  functions:
  public fn __init.Test_rc2() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_rc2.main() -> i64:
    entry: bb0
  
    bb0:
      gc_cycle
      %Sy_var0:obj = object_create{size=1:i64 record{fields=1 tag=0 [i64]}}
      
      obj_set(%Sy_var0:obj, 0:i64, 1:i64):i64
      gc_cycle
      %Sy_var1:obj = object_create{size=1:i64 record{fields=1 tag=0 [i64]}}
      
      obj_set(%Sy_var1:obj, 0:i64, 2:i64):i64
      %Sy_var2:i64 = obj_get(%Sy_var0:obj, 0:i64):i64
      rc_decr(%Sy_var0:obj)
      rc_check_release(%Sy_var0:obj)
      %Sy_var3:i64 = obj_get(%Sy_var1:obj, 0:i64):i64
      rc_decr(%Sy_var1:obj)
      rc_check_release(%Sy_var1:obj)
      %Sy_var4:i64 = %Sy_var2:i64 + %Sy_var3:i64
      return %Sy_var4:i64
  end
  
  end

Closure with captured variable:
  $ cat >test_rc3.sy <<EOF
  > let add x y = x + y
  > let apply f x = f x
  > fn main () =
  >     let r = apply (add 10) 20
  > EOF
  $ dune exec sylic -- oir test_rc3.sy
  module Test_rc3 :
  functions:
  public fn __init.Test_rc3() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_rc3.main() -> i64:
    entry: bb0
  
    bb0:
      gc_cycle
      %Sy_var0:*void = object_create{size=2:i32 record{fields=2 tag=0 [fn_ptr; i64]}}
      
      %Sy_accum_fn_0:fn_ptr = addr_fn(__make_closure_accum.syliTest_rc3.add.55_ret_i64)
      obj_set(%Sy_var0:*void, 0:i32, %Sy_accum_fn_0:fn_ptr):fn_ptr
      obj_set(%Sy_var0:*void, 1:i32, 10:i64):i64
      
      %Sy_var1:i64 = #call_direct syliTest_rc3.apply__fn_i64_i64__i64_ret_i64 (%Sy_var0:*void, 20:i64)
      rc_decr(%Sy_var0:*void)
      rc_check_release(%Sy_var0:*void)
      return %Sy_var1:i64
  end
  
  public fn syliTest_rc3.apply__fn_i64_i64__i64_ret_i64(%f:*void, %x:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_accum_ptr_1:fn_ptr = obj_get(%f:*void, 0:i32):fn_ptr
      %Sy_var0:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_1:fn_ptr)  (%x:i64, %f:*void, 0:i64)
      
      return %Sy_var0:i64
  end
  
  public fn syliTest_rc3.add__i64__i64_ret_i64(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 + %y:i64
      return %Sy_var0:i64
  end
  
  private fn __make_closure_accum.syliTest_rc3.add.55_ret_i64(%Sy_x0:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 1:i64):i64
      %Sy_rst:i64 = #call_direct __wrapper.syliTest_rc3.add.i64_i64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64)
      return %Sy_rst:i64
  end
  
  private fn __wrapper.syliTest_rc3.add.i64_i64_ret_i64(%Sy_x0:i64, %Sy_x1:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_s0:i64 = cast(%Sy_x0:i64 as i64)
      %Sy_s1:i64 = cast(%Sy_x1:i64 as i64)
      %Sy_rst:i64 = #call_direct syliTest_rc3.add__i64__i64_ret_i64 (%Sy_s0:i64, %Sy_s1:i64)
      return %Sy_rst:i64
  end
  
  end

Closure returned from function — verifies the returned closure is NOT released before the return:
  $ cat >test_rc_returned.sy <<EOF
  > let add x y = x + y
  > let make_adder n = add n
  > fn main () =
  >     let f = make_adder 10
  >     let r = f 5
  > EOF
  $ dune exec sylic -- oir test_rc_returned.sy
  module Test_rc_returned :
  functions:
  public fn __init.Test_rc_returned() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_rc_returned.main() -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:*void = #call_direct syliTest_rc_returned.make_adder__i64_ret_fn_i64_i64 (10:i64)
      %Sy_accum_ptr_0:fn_ptr = obj_get(%Sy_var0:*void, 0:i32):fn_ptr
      %Sy_var1:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_0:fn_ptr)  (5:i64, %Sy_var0:*void, 0:i64)
      rc_decr(%Sy_var0:*void)
      rc_check_release(%Sy_var0:*void)
      
      return %Sy_var1:i64
  end
  
  public fn syliTest_rc_returned.make_adder__i64_ret_fn_i64_i64(%n:i64) -> *void:
    entry: bb0
  
    bb0:
      gc_cycle
      %Sy_var0:*void = object_create{size=2:i32 record{fields=2 tag=0 [fn_ptr; i64]}}
      
      %Sy_accum_fn_1:fn_ptr = addr_fn(__make_closure_accum.syliTest_rc_returned.add.30_ret_i64)
      obj_set(%Sy_var0:*void, 0:i32, %Sy_accum_fn_1:fn_ptr):fn_ptr
      obj_set(%Sy_var0:*void, 1:i32, %n:i64):i64
      
      return %Sy_var0:*void
  end
  
  private fn __make_closure_accum.syliTest_rc_returned.add.30_ret_i64(%Sy_x0:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 1:i64):i64
      %Sy_rst:i64 = #call_direct __wrapper.syliTest_rc_returned.add.i64_i64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64)
      return %Sy_rst:i64
  end
  
  private fn __wrapper.syliTest_rc_returned.add.i64_i64_ret_i64(%Sy_x0:i64, %Sy_x1:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_s0:i64 = cast(%Sy_x0:i64 as i64)
      %Sy_s1:i64 = cast(%Sy_x1:i64 as i64)
      %Sy_rst:i64 = #call_direct syliTest_rc_returned.add__i64__i64_ret_i64 (%Sy_s0:i64, %Sy_s1:i64)
      return %Sy_rst:i64
  end
  
  end

Closure compose — two closures passed as borrowed parameters, released in caller after call:
  $ cat >test_rc_compose.sy <<EOF
  > let add x y = x + y
  > let compose f g x = f (g x)
  > fn main () =
  >     let r = compose (add 10) (add 20) 5
  > EOF
  $ dune exec sylic -- oir test_rc_compose.sy
  module Test_rc_compose :
  functions:
  public fn __init.Test_rc_compose() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_rc_compose.main() -> i64:
    entry: bb0
  
    bb0:
      gc_cycle
      %Sy_var0:*void = object_create{size=2:i32 record{fields=2 tag=0 [fn_ptr; i64]}}
      
      %Sy_accum_fn_0:fn_ptr = addr_fn(__make_closure_accum.syliTest_rc_compose.add.69_ret_i64)
      obj_set(%Sy_var0:*void, 0:i32, %Sy_accum_fn_0:fn_ptr):fn_ptr
      obj_set(%Sy_var0:*void, 1:i32, 10:i64):i64
      
      gc_cycle
      %Sy_var1:*void = object_create{size=2:i32 record{fields=2 tag=0 [fn_ptr; i64]}}
      
      %Sy_accum_fn_1:fn_ptr = addr_fn(__make_closure_accum.syliTest_rc_compose.add.76_ret_i64)
      obj_set(%Sy_var1:*void, 0:i32, %Sy_accum_fn_1:fn_ptr):fn_ptr
      obj_set(%Sy_var1:*void, 1:i32, 20:i64):i64
      
      %Sy_var2:i64 = #call_direct syliTest_rc_compose.compose__fn_i64_i64__fn_i64_i64__i64_ret_i64 (%Sy_var0:*void, %Sy_var1:*void, 5:i64)
      rc_decr(%Sy_var1:*void)
      rc_check_release(%Sy_var1:*void)
      rc_decr(%Sy_var0:*void)
      rc_check_release(%Sy_var0:*void)
      return %Sy_var2:i64
  end
  
  public fn syliTest_rc_compose.compose__fn_i64_i64__fn_i64_i64__i64_ret_i64(%f:*void, %g:*void, %x:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_accum_ptr_2:fn_ptr = obj_get(%g:*void, 0:i32):fn_ptr
      %Sy_var0:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_2:fn_ptr)  (%x:i64, %g:*void, 0:i64)
      
      %Sy_accum_ptr_3:fn_ptr = obj_get(%f:*void, 0:i32):fn_ptr
      %Sy_var1:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_3:fn_ptr)  (%Sy_var0:i64, %f:*void, 0:i64)
      
      return %Sy_var1:i64
  end
  
  public fn syliTest_rc_compose.add__i64__i64_ret_i64(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 + %y:i64
      return %Sy_var0:i64
  end
  
  private fn __make_closure_accum.syliTest_rc_compose.add.69_ret_i64(%Sy_x0:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 1:i64):i64
      %Sy_rst:i64 = #call_direct __wrapper.syliTest_rc_compose.add.i64_i64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64)
      return %Sy_rst:i64
  end
  
  private fn __make_closure_accum.syliTest_rc_compose.add.76_ret_i64(%Sy_x0:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 1:i64):i64
      %Sy_rst:i64 = #call_direct __wrapper.syliTest_rc_compose.add.i64_i64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64)
      return %Sy_rst:i64
  end
  
  private fn __wrapper.syliTest_rc_compose.add.i64_i64_ret_i64(%Sy_x0:i64, %Sy_x1:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_s0:i64 = cast(%Sy_x0:i64 as i64)
      %Sy_s1:i64 = cast(%Sy_x1:i64 as i64)
      %Sy_rst:i64 = #call_direct syliTest_rc_compose.add__i64__i64_ret_i64 (%Sy_s0:i64, %Sy_s1:i64)
      return %Sy_rst:i64
  end
  
  end

Closure apply_twice — borrowed closure applied twice, still only released in caller:
  $ cat >test_rc_twice.sy <<EOF
  > let add x y = x + y
  > let apply f x = f x
  > let apply_twice f x = f (f x)
  > fn main () =
  >     let r = apply_twice (add 1) 10
  > EOF
  $ dune exec sylic -- oir test_rc_twice.sy
  module Test_rc_twice :
  functions:
  public fn __init.Test_rc_twice() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_rc_twice.main() -> i64:
    entry: bb0
  
    bb0:
      gc_cycle
      %Sy_var0:*void = object_create{size=2:i32 record{fields=2 tag=0 [fn_ptr; i64]}}
      
      %Sy_accum_fn_0:fn_ptr = addr_fn(__make_closure_accum.syliTest_rc_twice.add.87_ret_i64)
      obj_set(%Sy_var0:*void, 0:i32, %Sy_accum_fn_0:fn_ptr):fn_ptr
      obj_set(%Sy_var0:*void, 1:i32, 1:i64):i64
      
      %Sy_var1:i64 = #call_direct syliTest_rc_twice.apply_twice__fn_i64_i64__i64_ret_i64 (%Sy_var0:*void, 10:i64)
      rc_decr(%Sy_var0:*void)
      rc_check_release(%Sy_var0:*void)
      return %Sy_var1:i64
  end
  
  public fn syliTest_rc_twice.apply_twice__fn_i64_i64__i64_ret_i64(%f:*void, %x:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_accum_ptr_1:fn_ptr = obj_get(%f:*void, 0:i32):fn_ptr
      %Sy_var0:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_1:fn_ptr)  (%x:i64, %f:*void, 0:i64)
      
      %Sy_accum_ptr_2:fn_ptr = obj_get(%f:*void, 0:i32):fn_ptr
      %Sy_var1:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_2:fn_ptr)  (%Sy_var0:i64, %f:*void, 0:i64)
      
      return %Sy_var1:i64
  end
  
  public fn syliTest_rc_twice.add__i64__i64_ret_i64(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 + %y:i64
      return %Sy_var0:i64
  end
  
  private fn __make_closure_accum.syliTest_rc_twice.add.87_ret_i64(%Sy_x0:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 1:i64):i64
      %Sy_rst:i64 = #call_direct __wrapper.syliTest_rc_twice.add.i64_i64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64)
      return %Sy_rst:i64
  end
  
  private fn __wrapper.syliTest_rc_twice.add.i64_i64_ret_i64(%Sy_x0:i64, %Sy_x1:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_s0:i64 = cast(%Sy_x0:i64 as i64)
      %Sy_s1:i64 = cast(%Sy_x1:i64 as i64)
      %Sy_rst:i64 = #call_direct syliTest_rc_twice.add__i64__i64_ret_i64 (%Sy_s0:i64, %Sy_s1:i64)
      return %Sy_rst:i64
  end
  
  end
