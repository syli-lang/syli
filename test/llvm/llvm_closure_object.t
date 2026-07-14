Closure with multipble chains of captured variables:
  $ cat >test_multi.sy <<EOF
  > let add x y z = x + y + z
  > let apply () =
  >   let add1 = add 1
  >   let add1and2 = add1 2
  >   add1and2 3
  > EOF
  $ dune exec sylic -- llvm test_multi.sy
  declare void @syli_rt_gc_cycle()
  declare void @syli_rt_object_check_release(ptr)
  declare void @syli_rt_object_decr(ptr)
  declare ptr @syli_rt_rc_alloc_object(i64, i32, i32)
  
  define void @__init.Test_multi() {
  bb0:
    ret void
  }
  
  define i64 @syliTest_multi.apply() {
  bb0:
    call void @syli_rt_gc_cycle()
    %Sy_var0 = call ptr @syli_rt_rc_alloc_object(i64 3602879701896462337, i32 1, i32 2)
    ; nop
    %Sy_accum_fn_0 = bitcast ptr @__make_closure_accum.syliTest_multi.add.41_ret_i64 to ptr
    %Sy_tmp0 = getelementptr i64, ptr %Sy_var0, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i32 0
    store ptr %Sy_accum_fn_0, ptr %Sy_tmp1
    %Sy_tmp2 = getelementptr i64, ptr %Sy_var0, i32 2
    %Sy_tmp3 = getelementptr i64, ptr %Sy_tmp2, i32 1
    store i64 1, ptr %Sy_tmp3
    ; nop
    call void @syli_rt_gc_cycle()
    %Sy_var1 = call ptr @syli_rt_rc_alloc_object(i64 3602879701896462338, i32 1, i32 3)
    ; nop
    %Sy_accum_fn_1 = bitcast ptr @__partial_closure_accum.clos1_arg1_ret_i64 to ptr
    %Sy_tmp4 = getelementptr i64, ptr %Sy_var1, i32 2
    %Sy_tmp5 = getelementptr i64, ptr %Sy_tmp4, i32 0
    store ptr %Sy_accum_fn_1, ptr %Sy_tmp5
    %Sy_tmp6 = getelementptr i64, ptr %Sy_var1, i32 2
    %Sy_tmp7 = getelementptr i64, ptr %Sy_tmp6, i32 1
    store ptr %Sy_var0, ptr %Sy_tmp7
    call void @syli_rt_object_decr(ptr %Sy_var0)
    call void @syli_rt_object_check_release(ptr %Sy_var0)
    %Sy_tmp8 = getelementptr i64, ptr %Sy_var1, i32 2
    %Sy_tmp9 = getelementptr i64, ptr %Sy_tmp8, i32 2
    store i64 2, ptr %Sy_tmp9
    ; nop
    %Sy_tmp10 = getelementptr i64, ptr %Sy_var1, i32 2
    %Sy_tmp11 = getelementptr i64, ptr %Sy_tmp10, i32 0
    %Sy_accum_ptr_2 = load ptr, ptr %Sy_tmp11
    %Sy_var2 = call i64 %Sy_accum_ptr_2(i64 3, ptr %Sy_var1, i64 0)
    call void @syli_rt_object_decr(ptr %Sy_var1)
    call void @syli_rt_object_check_release(ptr %Sy_var1)
    ; nop
    ret i64 %Sy_var2
  }
  
  define i64 @syliTest_multi.add__i64__i64__i64_ret_i64(i64 %x, i64 %y, i64 %z) {
  bb0:
    %Sy_var0 = add i64 %x, %y
    %Sy_var1 = add i64 %Sy_var0, %z
    ret i64 %Sy_var1
  }
  
  define i64 @__make_closure_accum.syliTest_multi.add.41_ret_i64(i64 %Sy_x0, i64 %Sy_x1, ptr %Sy_clos, i64 %Sy_dp_id) {
  bb0:
    %Sy_tmp0 = getelementptr i64, ptr %Sy_clos, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i64 1
    %Sy_val0 = load i64, ptr %Sy_tmp1
    %Sy_rst = call i64 @__wrapper.syliTest_multi.add.i64_i64_i64_ret_i64(i64 %Sy_val0, i64 %Sy_x0, i64 %Sy_x1)
    ret i64 %Sy_rst
  }
  
  define i64 @__partial_closure_accum.clos1_arg1_ret_i64(i64 %Sy_x0, ptr %Sy_clos, i64 %Sy_dp_id) {
  bb0:
    %Sy_tmp0 = getelementptr i64, ptr %Sy_clos, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i64 1
    %Sy_p_clos = load ptr, ptr %Sy_tmp1
    %Sy_tmp2 = getelementptr i64, ptr %Sy_p_clos, i32 2
    %Sy_tmp3 = getelementptr i64, ptr %Sy_tmp2, i64 0
    %Sy_p_accum = load ptr, ptr %Sy_tmp3
    %Sy_tmp4 = getelementptr i64, ptr %Sy_clos, i32 2
    %Sy_tmp5 = getelementptr i64, ptr %Sy_tmp4, i64 2
    %Sy_val0 = load i64, ptr %Sy_tmp5
    %Sy_rst = call i64 %Sy_p_accum(i64 %Sy_val0, i64 %Sy_x0, ptr %Sy_p_clos, i64 %Sy_dp_id)
    ret i64 %Sy_rst
  }
  
  define i64 @__wrapper.syliTest_multi.add.i64_i64_i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1, i64 %Sy_x2) {
  bb0:
    %Sy_rst = call i64 @syliTest_multi.add__i64__i64__i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1, i64 %Sy_x2)
    ret i64 %Sy_rst
  }
  
Closure as an argument:
  $ cat >test_multi.sy <<EOF
  > let add x y = x + y
  > let apply f x y = f x y
  > let result = apply add 3 4
  > EOF
  $ dune exec sylic -- llvm test_multi.sy
  declare void @syli_rt_gc_cycle()
  declare void @syli_rt_object_check_release(ptr)
  declare void @syli_rt_object_decr(ptr)
  declare ptr @syli_rt_rc_alloc_object(i64, i32, i32)
  
  @syliTest_multi.result = global i64 zeroinitializer
  
  define void @__init.Test_multi() {
  bb0:
    %__init_tmp_0 = call i64 @__init_global.syliTest_multi.result()
    store i64 %__init_tmp_0, ptr @syliTest_multi.result
    ret void
  }
  
  define i64 @__init_global.syliTest_multi.result() {
  bb0:
    call void @syli_rt_gc_cycle()
    %Sy_var0 = call ptr @syli_rt_rc_alloc_object(i64 3026418949592973313, i32 1, i32 1)
    ; nop
    %Sy_accum_fn_0 = bitcast ptr @__make_closure_accum.syliTest_multi.add.62_ret_i64 to ptr
    %Sy_tmp0 = getelementptr i64, ptr %Sy_var0, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i32 0
    store ptr %Sy_accum_fn_0, ptr %Sy_tmp1
    ; nop
    %Sy_var1 = call i64 @syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64(ptr %Sy_var0, i64 3, i64 4)
    call void @syli_rt_object_decr(ptr %Sy_var0)
    call void @syli_rt_object_check_release(ptr %Sy_var0)
    ret i64 %Sy_var1
  }
  
  define i64 @syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64(ptr %f, i64 %x, i64 %y) {
  bb0:
    %Sy_tmp0 = getelementptr i64, ptr %f, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i32 0
    %Sy_accum_ptr_1 = load ptr, ptr %Sy_tmp1
    %Sy_var0 = call i64 %Sy_accum_ptr_1(i64 %x, i64 %y, ptr %f, i64 0)
    ; nop
    ret i64 %Sy_var0
  }
  
  define i64 @syliTest_multi.add__i64__i64_ret_i64(i64 %x, i64 %y) {
  bb0:
    %Sy_var0 = add i64 %x, %y
    ret i64 %Sy_var0
  }
  
  define i64 @__make_closure_accum.syliTest_multi.add.62_ret_i64(i64 %Sy_x0, i64 %Sy_x1, ptr %Sy_clos, i64 %Sy_dp_id) {
  bb0:
    %Sy_rst = call i64 @__wrapper.syliTest_multi.add.i64_i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1)
    ret i64 %Sy_rst
  }
  
  define i64 @__wrapper.syliTest_multi.add.i64_i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1) {
  bb0:
    %Sy_rst = call i64 @syliTest_multi.add__i64__i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1)
    ret i64 %Sy_rst
  }
  
