Closure as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > let apply f x y = f x y
  > let add x y z = x
  > fn main () =
  >   let add1 = add 1
  >   let result =
  >     if true then
  >       apply add1 3 4
  >     else apply add1 1.0 2.0
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
      %Sy_var1:bool = cast(true:bool as bool)
      cond_br %Sy_var1:bool, bb1, bb2
  
    bb1:
      %Sy_var3:(i64, i64 -> i64) = cast(%Sy_var0:(?88, ?89 -> i64) as (i64, i64 -> i64))
      %Sy_var4:i64 = #call_direct syliTest_multi.apply (%Sy_var3:(i64, i64 -> i64), 3:i64, 4:i64)
      %Sy_var2:i64 = move(%Sy_var4:i64)
      goto bb3
  
    bb2:
      %Sy_var5:(f64, f64 -> i64) = cast(%Sy_var0:(?88, ?89 -> i64) as (f64, f64 -> i64))
      %Sy_var6:i64 = #call_direct syliTest_multi.apply (%Sy_var5:(f64, f64 -> i64), 1.0f:f64, 2.0f:f64)
      %Sy_var2:i64 = move(%Sy_var6:i64)
      goto bb3
  
    bb3:
  
      return %Sy_var2:i64
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

  $ dune exec sylic -- typing test_multi.sy
  Typed test_multi.sy successfully: module Test_multi with 3 top-level typed items
  Type Environment:
  {
    add : forall '79 '81 '83. ('79, '81, '83) -> '79
    apply : forall '71 '73 '77. (('71, '73) -> '77, '71, '73) -> '77
    main : (unit) -> int64
  }

  $ dune exec sylic -- oir test_multi.sy
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
      gc_cycle
      %Sy_var0:*void = object_create{size=2:i32 record{fields=2 tag=0 [fn_ptr; i64]}}
      
      %Sy_accum_fn_0:fn_ptr = addr_fn(__make_closure_accum.dispatch.66_ret_i64)
      obj_set(%Sy_var0:*void, 0:i32, %Sy_accum_fn_0:fn_ptr):fn_ptr
      obj_set(%Sy_var0:*void, 1:i32, 1:i64):i64
      
      %Sy_var1:bool = cast(true:bool as bool)
      cond_br %Sy_var1:bool, bb1, bb2
  
    bb2:
      gc_cycle
      %Sy_var5:*void = object_create{size=3:i32 record{fields=3 tag=0 [fn_ptr; i64; *void]}}
      
      %Sy_accum_fn_1:fn_ptr = addr_fn(__partial_closure_accum.dispatch.clos0_arg2_ret_i64)
      obj_set(%Sy_var5:*void, 0:i32, %Sy_accum_fn_1:fn_ptr):fn_ptr
      obj_set(%Sy_var5:*void, 1:i32, 1:i64):i64
      obj_set(%Sy_var5:*void, 2:i32, %Sy_var0:*void):*void
      rc_decr(%Sy_var0:*void)
      rc_check_release(%Sy_var0:*void)
      
      %Sy_var6:i64 = #call_direct syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64 (%Sy_var5:*void, 1.0f:f64, 2.0f:f64)
      rc_decr(%Sy_var5:*void)
      rc_check_release(%Sy_var5:*void)
      %Sy_var2:i64 = move(%Sy_var6:i64)
      goto bb3
  
    bb1:
      gc_cycle
      %Sy_var3:*void = object_create{size=2:i32 record{fields=2 tag=0 [fn_ptr; *void]}}
      
      %Sy_accum_fn_2:fn_ptr = addr_fn(__partial_closure_accum.clos0_arg2_ret_i64)
      obj_set(%Sy_var3:*void, 0:i32, %Sy_accum_fn_2:fn_ptr):fn_ptr
      obj_set(%Sy_var3:*void, 1:i32, %Sy_var0:*void):*void
      rc_decr(%Sy_var0:*void)
      rc_check_release(%Sy_var0:*void)
      
      %Sy_var4:i64 = #call_direct syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64 (%Sy_var3:*void, 3:i64, 4:i64)
      rc_decr(%Sy_var3:*void)
      rc_check_release(%Sy_var3:*void)
      %Sy_var2:i64 = move(%Sy_var4:i64)
      goto bb3
  
    bb3:
  
      return %Sy_var2:i64
  end
  
  public fn syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64(%f:*void, %x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_accum_ptr_3:fn_ptr = obj_get(%f:*void, 0:i32):fn_ptr
      %Sy_var0:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_3:fn_ptr)  (%x:i64, %y:i64, %f:*void, 0:i64)
      
      return %Sy_var0:i64
  end
  
  public fn syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64(%f:*void, %x:f64, %y:f64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_accum_ptr_4:fn_ptr = obj_get(%f:*void, 0:i32):fn_ptr
      %Sy_apply_cast_5:i64 = cast(%x:f64 as i64)
      %Sy_apply_cast_6:i64 = cast(%y:f64 as i64)
      %Sy_var0:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_4:fn_ptr)  (%Sy_apply_cast_5:i64, %Sy_apply_cast_6:i64, %f:*void, 0:i64)
      
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
  
  private fn __make_closure_accum.dispatch.66_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb-1
  
    bb-1:
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 1:i64):i64
      switch %Sy_dp_id:i64 [1: bb1, 0: bb0]
  
    bb1:
      %Sy_case_result1:i64 = #call_direct __wrapper.syliTest_multi.add.i64_f64_f64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64, %Sy_x1:i64)
      return %Sy_case_result1:i64
  
    bb0:
      %Sy_case_result0:i64 = #call_direct __wrapper.syliTest_multi.add.i64_i64_i64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64, %Sy_x1:i64)
      return %Sy_case_result0:i64
  end
  
  private fn __partial_closure_accum.clos0_arg2_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_p_clos:*void = obj_get(%Sy_clos:*void, 1:i64):*void
      %Sy_p_accum:fn_ptr = obj_get(%Sy_p_clos:*void, 0:i64):fn_ptr
      %Sy_rst:i64 = #call_direct_fn_ptr(%Sy_p_accum:fn_ptr)  (%Sy_x0:i64, %Sy_x1:i64, %Sy_p_clos:*void, %Sy_dp_id:i64)
      return %Sy_rst:i64
  end
  
  private fn __partial_closure_accum.dispatch.clos0_arg2_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_dp_clos:i64 = obj_get(%Sy_clos:*void, 1:i64):i64
      %Sy_accum_dp_id:i64 = %Sy_dp_id:i64 + %Sy_dp_clos:i64
      %Sy_p_clos:*void = obj_get(%Sy_clos:*void, 2:i64):*void
      %Sy_p_accum:fn_ptr = obj_get(%Sy_p_clos:*void, 0:i64):fn_ptr
      %Sy_rst:i64 = #call_direct_fn_ptr(%Sy_p_accum:fn_ptr)  (%Sy_x0:i64, %Sy_x1:i64, %Sy_p_clos:*void, %Sy_accum_dp_id:i64)
      return %Sy_rst:i64
  end
  
  private fn __wrapper.syliTest_multi.add.i64_f64_f64_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_x2:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_s0:i64 = cast(%Sy_x0:i64 as i64)
      %Sy_s1:f64 = cast(%Sy_x1:i64 as f64)
      %Sy_s2:f64 = cast(%Sy_x2:i64 as f64)
      %Sy_rst:i64 = #call_direct syliTest_multi.add__i64__f64__f64_ret_i64 (%Sy_s0:i64, %Sy_s1:f64, %Sy_s2:f64)
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
