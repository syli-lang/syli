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
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  let syliTest_multi.apply = fun (f, x, y) : 'a77 ->
      f(x : 'a71, y : 'a73) : 'a77
  
  let syliTest_multi.add = fun (x, y, z) : 'a79 ->
      x : 'a79
  
  let syliTest_multi.main = fun () : i64 ->
      {
        let syliTest_multi.main__add1 = syliTest_multi.add(1 : i64) : ('a88, 'a89) -> i64
        let syliTest_multi.main__result = if true : bool
            syliTest_multi.apply(syliTest_multi.main__add1 : (i64, i64) -> i64, 3 : i64, 4 : i64) : i64
          else
            syliTest_multi.apply(syliTest_multi.main__add1 : (double, double) -> i64, 1.0 : double, 2.0 : double) : i64
      }
  
  $ dune exe sylic -- oir test_multi.sy
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
      %Sy_var0:obj{{card=2 [0:fn_ptr; 1:i64]} tag=0 unknow_cyclic} = object_create{size=2:i32}
      
      %Sy_accum_fn_0:fn_ptr = addr_fn(__make_closure_accum.dispatch.65_ret_i64)
      obj_set(%Sy_var0:obj_ptr, 0:i32, %Sy_accum_fn_0:fn_ptr):fn_ptr
      obj_set(%Sy_var0:obj_ptr, 1:i32, 1:i64):i64
      
      %Sy_var1:bool = cast(true:bool as bool)
      cond_br %Sy_var1:bool, bb1, bb2
  
    bb2:
      gc_cycle
      %Sy_var5:obj{{card=3 [0:fn_ptr; 1:i64; 2:obj_ptr]} tag=0 unknow_cyclic} = object_create{size=3:i32}
      
      %Sy_accum_fn_1:fn_ptr = addr_fn(__partial_closure_accum.dispatch.clos0_arg2_ret_i64)
      obj_set(%Sy_var5:obj_ptr, 0:i32, %Sy_accum_fn_1:fn_ptr):fn_ptr
      obj_set(%Sy_var5:obj_ptr, 1:i32, 1:i64):i64
      %Sy_release_tmp_1:obj_ptr = @transfer obj_get(%Sy_var5:obj_ptr, 2:i32):obj_ptr
      release(%Sy_release_tmp_1:obj_ptr)
      obj_set(%Sy_var5:obj_ptr, 2:i32, @own %Sy_var0:obj_ptr):obj_ptr
      
      %Sy_var6:i64 = #call_direct syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64 (@transfer %Sy_var5:obj_ptr, 1.0f:f64, 2.0f:f64)
      %Sy_var2:i64 = move(%Sy_var6:i64)
      goto bb3
  
    bb1:
      gc_cycle
      %Sy_var3:obj{{card=2 [0:fn_ptr; 1:obj_ptr]} tag=0 unknow_cyclic} = object_create{size=2:i32}
      
      %Sy_accum_fn_2:fn_ptr = addr_fn(__partial_closure_accum.clos0_arg2_ret_i64)
      obj_set(%Sy_var3:obj_ptr, 0:i32, %Sy_accum_fn_2:fn_ptr):fn_ptr
      %Sy_release_tmp_2:obj_ptr = @transfer obj_get(%Sy_var3:obj_ptr, 1:i32):obj_ptr
      release(%Sy_release_tmp_2:obj_ptr)
      obj_set(%Sy_var3:obj_ptr, 1:i32, @own %Sy_var0:obj_ptr):obj_ptr
      
      %Sy_var4:i64 = #call_direct syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64 (@transfer %Sy_var3:obj_ptr, 3:i64, 4:i64)
      %Sy_var2:i64 = move(%Sy_var4:i64)
      goto bb3
  
    bb3:
  
      return %Sy_var2:i64
  end
  
  public fn syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64(%f:obj_ptr, %x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_accum_ptr_3:fn_ptr = obj_get(%f:obj_ptr, 0:i32):fn_ptr
      %Sy_var0:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_3:fn_ptr)  (%x:i64, %y:i64, @transfer %f:obj_ptr, 0:i64)
      
      return %Sy_var0:i64
  end
  
  public fn syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64(%f:obj_ptr, %x:f64, %y:f64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_accum_ptr_4:fn_ptr = obj_get(%f:obj_ptr, 0:i32):fn_ptr
      %Sy_apply_cast_5:i64 = cast(%x:f64 as i64)
      %Sy_apply_cast_6:i64 = cast(%y:f64 as i64)
      %Sy_var0:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_4:fn_ptr)  (%Sy_apply_cast_5:i64, %Sy_apply_cast_6:i64, @transfer %f:obj_ptr, 0:i64)
      
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
  
  private fn __make_closure_accum.dispatch.65_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_clos:obj_ptr, %Sy_dp_id:i64) -> i64:
    entry: bb-1
  
    bb-1:
      %Sy_val0:i64 = obj_get(%Sy_clos:obj_ptr, 1:i64):i64
      release(%Sy_clos:obj_ptr)
      switch %Sy_dp_id:i64 [1: bb1, 0: bb0]
  
    bb1:
      %Sy_case_result1:i64 = #call_direct __wrapper.syliTest_multi.add.i64_f64_f64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64, %Sy_x1:i64)
      return %Sy_case_result1:i64
  
    bb0:
      %Sy_case_result0:i64 = #call_direct __wrapper.syliTest_multi.add.i64_i64_i64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64, %Sy_x1:i64)
      return %Sy_case_result0:i64
  end
  
  private fn __partial_closure_accum.clos0_arg2_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_clos:obj_ptr, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_p_clos:obj_ptr = @share obj_get(%Sy_clos:obj_ptr, 1:i64):obj_ptr
      release(%Sy_clos:obj_ptr)
      %Sy_p_accum:fn_ptr = obj_get(%Sy_p_clos:obj_ptr, 0:i64):fn_ptr
      %Sy_rst:i64 = #call_direct_fn_ptr(%Sy_p_accum:fn_ptr)  (%Sy_x0:i64, %Sy_x1:i64, @transfer %Sy_p_clos:obj_ptr, %Sy_dp_id:i64)
      return %Sy_rst:i64
  end
  
  private fn __partial_closure_accum.dispatch.clos0_arg2_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_clos:obj_ptr, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_dp_clos:i64 = obj_get(%Sy_clos:obj_ptr, 1:i64):i64
      %Sy_accum_dp_id:i64 = %Sy_dp_id:i64 + %Sy_dp_clos:i64
      %Sy_p_clos:obj_ptr = @share obj_get(%Sy_clos:obj_ptr, 2:i64):obj_ptr
      release(%Sy_clos:obj_ptr)
      %Sy_p_accum:fn_ptr = obj_get(%Sy_p_clos:obj_ptr, 0:i64):fn_ptr
      %Sy_rst:i64 = #call_direct_fn_ptr(%Sy_p_accum:fn_ptr)  (%Sy_x0:i64, %Sy_x1:i64, @transfer %Sy_p_clos:obj_ptr, %Sy_accum_dp_id:i64)
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

  $ dune exec sylic -- llvm test_multi.sy > test_multi.ll
  $ cat test_multi.ll
  declare void @syli_rt_gc_cycle()
  declare ptr addrspace(1) @syli_rt_ownership_alloc_object(i64, i32, i32)
  declare void @syli_rt_ownership_decr(ptr addrspace(1))
  declare void @syli_rt_ownership_incr(ptr addrspace(1))
  declare void @syli_rt_ownership_notify_mutation(ptr addrspace(1), ptr addrspace(1))
  declare ptr addrspace(1) @syli_rt_ownership_share(ptr addrspace(1))
  
  define i32 @syli_startup_program(i32 %argc, ptr %argv) gc "statepoint-example" {
  bb0:
    call void @syli_modules_init()
    %__dropped_main_ret = call i64 @syliTest_multi.main()
    ret i32 0
  }
  
  define void @syli_modules_init() gc "statepoint-example" {
  bb0:
    call void @__init.Test_multi()
    ret void
  }
  
  define void @__init.Test_multi() gc "statepoint-example" {
  bb0:
    ret void
  }
  
  define i64 @syliTest_multi.main() gc "statepoint-example" {
  bb0:
    %Sy_var2 = alloca i64
    call void @syli_rt_gc_cycle()
    %Sy_var0 = call ptr addrspace(1) @syli_rt_ownership_alloc_object(i64 2377900603251621890, i32 1, i32 2)
    ; nop
    %Sy_accum_fn_0 = bitcast ptr @__make_closure_accum.dispatch.65_ret_i64 to ptr
    %Sy_tmp0 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var0)
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp0, i32 0, i32 2, i32 0
    store ptr %Sy_accum_fn_0, ptr addrspace(1) %Sy_tmp1
    %Sy_tmp2 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var0)
    %Sy_tmp3 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp2, i32 0, i32 2, i32 1
    store i64 1, ptr addrspace(1) %Sy_tmp3
    ; nop
    br i1 true, label %bb1, label %bb2
  bb2:
    call void @syli_rt_gc_cycle()
    %Sy_var5 = call ptr addrspace(1) @syli_rt_ownership_alloc_object(i64 4251398048237748355, i32 1, i32 3)
    ; nop
    %Sy_accum_fn_1 = bitcast ptr @__partial_closure_accum.dispatch.clos0_arg2_ret_i64 to ptr
    %Sy_tmp4 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var5)
    %Sy_tmp5 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp4, i32 0, i32 2, i32 0
    store ptr %Sy_accum_fn_1, ptr addrspace(1) %Sy_tmp5
    %Sy_tmp6 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var5)
    %Sy_tmp7 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp6, i32 0, i32 2, i32 1
    store i64 1, ptr addrspace(1) %Sy_tmp7
    %Sy_tmp8 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var5)
    %Sy_tmp9 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp8, i32 0, i32 2, i32 2
    %Sy_release_tmp_1 = load ptr addrspace(1), ptr addrspace(1) %Sy_tmp9
    call void @syli_inlinable_ownership_release(ptr addrspace(1) %Sy_release_tmp_1)
    %Sy_tmp_1 = call ptr addrspace(1) @syli_inlinable_ownership_own(ptr addrspace(1) %Sy_var0)
    %Sy_tmp10 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var5)
    %Sy_tmp11 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp10, i32 0, i32 2, i32 2
    store ptr addrspace(1) %Sy_tmp_1, ptr addrspace(1) %Sy_tmp11
    call void @syli_rt_ownership_notify_mutation(ptr addrspace(1) %Sy_var5, ptr addrspace(1) %Sy_tmp_1)
    ; nop
    %Sy_var6 = call i64 @syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64(ptr addrspace(1) %Sy_var5, double 1., double 2.)
    store i64 %Sy_var6, ptr %Sy_var2
    br label %bb3
  bb1:
    call void @syli_rt_gc_cycle()
    %Sy_var3 = call ptr addrspace(1) @syli_rt_ownership_alloc_object(i64 4251398048237748290, i32 1, i32 2)
    ; nop
    %Sy_accum_fn_2 = bitcast ptr @__partial_closure_accum.clos0_arg2_ret_i64 to ptr
    %Sy_tmp12 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var3)
    %Sy_tmp13 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp12, i32 0, i32 2, i32 0
    store ptr %Sy_accum_fn_2, ptr addrspace(1) %Sy_tmp13
    %Sy_tmp14 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var3)
    %Sy_tmp15 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp14, i32 0, i32 2, i32 1
    %Sy_release_tmp_2 = load ptr addrspace(1), ptr addrspace(1) %Sy_tmp15
    call void @syli_inlinable_ownership_release(ptr addrspace(1) %Sy_release_tmp_2)
    %Sy_tmp_2 = call ptr addrspace(1) @syli_inlinable_ownership_own(ptr addrspace(1) %Sy_var0)
    %Sy_tmp16 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var3)
    %Sy_tmp17 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp16, i32 0, i32 2, i32 1
    store ptr addrspace(1) %Sy_tmp_2, ptr addrspace(1) %Sy_tmp17
    call void @syli_rt_ownership_notify_mutation(ptr addrspace(1) %Sy_var3, ptr addrspace(1) %Sy_tmp_2)
    ; nop
    %Sy_var4 = call i64 @syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64(ptr addrspace(1) %Sy_var3, i64 3, i64 4)
    store i64 %Sy_var4, ptr %Sy_var2
    br label %bb3
  bb3:
    %Sy_tmp18 = load i64, ptr %Sy_var2
    ret i64 %Sy_tmp18
  }
  
  define i64 @syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64(ptr addrspace(1) %f, i64 %x, i64 %y) gc "statepoint-example" {
  bb0:
    %Sy_tmp0 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %f)
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp0, i32 0, i32 2, i32 0
    %Sy_accum_ptr_3 = load ptr, ptr addrspace(1) %Sy_tmp1
    %Sy_var0 = call i64 %Sy_accum_ptr_3(i64 %x, i64 %y, ptr addrspace(1) %f, i64 0)
    ; nop
    ret i64 %Sy_var0
  }
  
  define i64 @syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64(ptr addrspace(1) %f, double %x, double %y) gc "statepoint-example" {
  bb0:
    %Sy_tmp0 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %f)
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp0, i32 0, i32 2, i32 0
    %Sy_accum_ptr_4 = load ptr, ptr addrspace(1) %Sy_tmp1
    %Sy_apply_cast_5 = bitcast double %x to i64
    %Sy_apply_cast_6 = bitcast double %y to i64
    %Sy_var0 = call i64 %Sy_accum_ptr_4(i64 %Sy_apply_cast_5, i64 %Sy_apply_cast_6, ptr addrspace(1) %f, i64 0)
    ; nop
    ret i64 %Sy_var0
  }
  
  define i64 @syliTest_multi.add__i64__i64__i64_ret_i64(i64 %x, i64 %y, i64 %z) gc "statepoint-example" {
  bb0:
    ret i64 %x
  }
  
  define i64 @syliTest_multi.add__i64__f64__f64_ret_i64(i64 %x, double %y, double %z) gc "statepoint-example" {
  bb0:
    ret i64 %x
  }
  
  define i64 @__make_closure_accum.dispatch.65_ret_i64(i64 %Sy_x0, i64 %Sy_x1, ptr addrspace(1) %Sy_clos, i64 %Sy_dp_id) gc "statepoint-example" {
  bb-1:
    %Sy_tmp0 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_clos)
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp0, i32 0, i32 2, i64 1
    %Sy_val0 = load i64, ptr addrspace(1) %Sy_tmp1
    call void @syli_inlinable_ownership_release(ptr addrspace(1) %Sy_clos)
    switch i64 %Sy_dp_id, label %switch_default_unreachable [
      i64 1, label %bb1
      i64 0, label %bb0
    ]
  bb1:
    %Sy_case_result1 = call i64 @__wrapper.syliTest_multi.add.i64_f64_f64_ret_i64(i64 %Sy_val0, i64 %Sy_x0, i64 %Sy_x1)
    ret i64 %Sy_case_result1
  bb0:
    %Sy_case_result0 = call i64 @__wrapper.syliTest_multi.add.i64_i64_i64_ret_i64(i64 %Sy_val0, i64 %Sy_x0, i64 %Sy_x1)
    ret i64 %Sy_case_result0
  switch_default_unreachable:
    unreachable
  }
  
  define i64 @__partial_closure_accum.clos0_arg2_ret_i64(i64 %Sy_x0, i64 %Sy_x1, ptr addrspace(1) %Sy_clos, i64 %Sy_dp_id) gc "statepoint-example" {
  bb0:
    %Sy_tmp0 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_clos)
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp0, i32 0, i32 2, i64 1
    %Sy_raw_tmp_3 = load ptr addrspace(1), ptr addrspace(1) %Sy_tmp1
    %Sy_p_clos = call ptr addrspace(1) @syli_rt_ownership_share(ptr addrspace(1) %Sy_raw_tmp_3)
    call void @syli_inlinable_ownership_release(ptr addrspace(1) %Sy_clos)
    %Sy_tmp2 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_p_clos)
    %Sy_tmp3 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp2, i32 0, i32 2, i64 0
    %Sy_p_accum = load ptr, ptr addrspace(1) %Sy_tmp3
    %Sy_rst = call i64 %Sy_p_accum(i64 %Sy_x0, i64 %Sy_x1, ptr addrspace(1) %Sy_p_clos, i64 %Sy_dp_id)
    ret i64 %Sy_rst
  }
  
  define i64 @__partial_closure_accum.dispatch.clos0_arg2_ret_i64(i64 %Sy_x0, i64 %Sy_x1, ptr addrspace(1) %Sy_clos, i64 %Sy_dp_id) gc "statepoint-example" {
  bb0:
    %Sy_tmp0 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_clos)
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp0, i32 0, i32 2, i64 1
    %Sy_dp_clos = load i64, ptr addrspace(1) %Sy_tmp1
    %Sy_accum_dp_id = add i64 %Sy_dp_id, %Sy_dp_clos
    %Sy_tmp2 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_clos)
    %Sy_tmp3 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp2, i32 0, i32 2, i64 2
    %Sy_raw_tmp_4 = load ptr addrspace(1), ptr addrspace(1) %Sy_tmp3
    %Sy_p_clos = call ptr addrspace(1) @syli_rt_ownership_share(ptr addrspace(1) %Sy_raw_tmp_4)
    call void @syli_inlinable_ownership_release(ptr addrspace(1) %Sy_clos)
    %Sy_tmp4 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_p_clos)
    %Sy_tmp5 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp4, i32 0, i32 2, i64 0
    %Sy_p_accum = load ptr, ptr addrspace(1) %Sy_tmp5
    %Sy_rst = call i64 %Sy_p_accum(i64 %Sy_x0, i64 %Sy_x1, ptr addrspace(1) %Sy_p_clos, i64 %Sy_accum_dp_id)
    ret i64 %Sy_rst
  }
  
  define i64 @__wrapper.syliTest_multi.add.i64_f64_f64_ret_i64(i64 %Sy_x0, i64 %Sy_x1, i64 %Sy_x2) gc "statepoint-example" {
  bb0:
    %Sy_s1 = bitcast i64 %Sy_x1 to double
    %Sy_s2 = bitcast i64 %Sy_x2 to double
    %Sy_rst = call i64 @syliTest_multi.add__i64__f64__f64_ret_i64(i64 %Sy_x0, double %Sy_s1, double %Sy_s2)
    ret i64 %Sy_rst
  }
  
  define i64 @__wrapper.syliTest_multi.add.i64_i64_i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1, i64 %Sy_x2) gc "statepoint-example" {
  bb0:
    %Sy_rst = call i64 @syliTest_multi.add__i64__i64__i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1, i64 %Sy_x2)
    ret i64 %Sy_rst
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -2
    %r = inttoptr i64 %u to ptr addrspace(1)
    ret ptr addrspace(1) %r
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_borrow(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -2
    %r = inttoptr i64 %u to ptr addrspace(1)
    ret ptr addrspace(1) %r
  }
  
  define void @syli_inlinable_ownership_release(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 1
    %is_own = icmp ne i64 %tag, 0
    br i1 %is_own, label %own, label %done
  own:
    call void @syli_rt_ownership_decr(ptr addrspace(1) %p)
    ret void
  done:
    ret void
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_own(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 1
    %is_borrow = icmp eq i64 %tag, 0
    br i1 %is_borrow, label %promote, label %done
  promote:
    %r = or i64 %pi, 1
    %rp = inttoptr i64 %r to ptr addrspace(1)
    call void @syli_rt_ownership_incr(ptr addrspace(1) %rp)
    ret ptr addrspace(1) %rp
  done:
    ret ptr addrspace(1) %p
  }
  
