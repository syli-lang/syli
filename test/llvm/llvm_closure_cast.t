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
  

  $ dune exec sylic -- llvm test_multi.sy > test_multi.ll
  $ cat test_multi.ll
  declare void @syli_rt_gc_cycle()
  declare void @syli_rt_object_check_release(ptr)
  declare void @syli_rt_object_decr(ptr)
  declare ptr @syli_rt_rc_alloc_object(i64, i32, i32)
  
  define i32 @syli_startup_program(i32 %argc, ptr %argv) {
  bb0:
    call void @syli_modules_init()
    %__dropped_main_ret = call i64 @syliTest_multi.main()
    ret i32 0
  }
  
  define void @syli_modules_init() {
  bb0:
    call void @__init.Test_multi()
    ret void
  }
  
  define void @__init.Test_multi() {
  bb0:
    ret void
  }
  
  define i64 @syliTest_multi.main() {
  bb0:
    %Sy_var2 = alloca i64
    call void @syli_rt_gc_cycle()
    %Sy_var0 = call ptr @syli_rt_rc_alloc_object(i64 2305843009213693954, i32 1, i32 2)
    ; nop
    %Sy_accum_fn_0 = bitcast ptr @__make_closure_accum.dispatch.66_ret_i64 to ptr
    %Sy_tmp0 = getelementptr i64, ptr %Sy_var0, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i32 0
    store ptr %Sy_accum_fn_0, ptr %Sy_tmp1
    %Sy_tmp2 = getelementptr i64, ptr %Sy_var0, i32 2
    %Sy_tmp3 = getelementptr i64, ptr %Sy_tmp2, i32 1
    store i64 1, ptr %Sy_tmp3
    ; nop
    br i1 true, label %bb1, label %bb2
  bb2:
    call void @syli_rt_gc_cycle()
    %Sy_var5 = call ptr @syli_rt_rc_alloc_object(i64 4179340454199820419, i32 1, i32 3)
    ; nop
    %Sy_accum_fn_1 = bitcast ptr @__partial_closure_accum.dispatch.clos0_arg2_ret_i64 to ptr
    %Sy_tmp4 = getelementptr i64, ptr %Sy_var5, i32 2
    %Sy_tmp5 = getelementptr i64, ptr %Sy_tmp4, i32 0
    store ptr %Sy_accum_fn_1, ptr %Sy_tmp5
    %Sy_tmp6 = getelementptr i64, ptr %Sy_var5, i32 2
    %Sy_tmp7 = getelementptr i64, ptr %Sy_tmp6, i32 1
    store i64 1, ptr %Sy_tmp7
    %Sy_tmp8 = getelementptr i64, ptr %Sy_var5, i32 2
    %Sy_tmp9 = getelementptr i64, ptr %Sy_tmp8, i32 2
    store ptr %Sy_var0, ptr %Sy_tmp9
    call void @syli_rt_object_decr(ptr %Sy_var0)
    call void @syli_rt_object_check_release(ptr %Sy_var0)
    ; nop
    %Sy_var6 = call i64 @syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64(ptr %Sy_var5, double 1., double 2.)
    call void @syli_rt_object_decr(ptr %Sy_var5)
    call void @syli_rt_object_check_release(ptr %Sy_var5)
    store i64 %Sy_var6, ptr %Sy_var2
    br label %bb3
  bb1:
    call void @syli_rt_gc_cycle()
    %Sy_var3 = call ptr @syli_rt_rc_alloc_object(i64 4179340454199820354, i32 1, i32 2)
    ; nop
    %Sy_accum_fn_2 = bitcast ptr @__partial_closure_accum.clos0_arg2_ret_i64 to ptr
    %Sy_tmp10 = getelementptr i64, ptr %Sy_var3, i32 2
    %Sy_tmp11 = getelementptr i64, ptr %Sy_tmp10, i32 0
    store ptr %Sy_accum_fn_2, ptr %Sy_tmp11
    %Sy_tmp12 = getelementptr i64, ptr %Sy_var3, i32 2
    %Sy_tmp13 = getelementptr i64, ptr %Sy_tmp12, i32 1
    store ptr %Sy_var0, ptr %Sy_tmp13
    call void @syli_rt_object_decr(ptr %Sy_var0)
    call void @syli_rt_object_check_release(ptr %Sy_var0)
    ; nop
    %Sy_var4 = call i64 @syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64(ptr %Sy_var3, i64 3, i64 4)
    call void @syli_rt_object_decr(ptr %Sy_var3)
    call void @syli_rt_object_check_release(ptr %Sy_var3)
    store i64 %Sy_var4, ptr %Sy_var2
    br label %bb3
  bb3:
    %Sy_tmp14 = load i64, ptr %Sy_var2
    ret i64 %Sy_tmp14
  }
  
  define i64 @syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64(ptr %f, i64 %x, i64 %y) {
  bb0:
    %Sy_tmp0 = getelementptr i64, ptr %f, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i32 0
    %Sy_accum_ptr_3 = load ptr, ptr %Sy_tmp1
    %Sy_var0 = call i64 %Sy_accum_ptr_3(i64 %x, i64 %y, ptr %f, i64 0)
    ; nop
    ret i64 %Sy_var0
  }
  
  define i64 @syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64(ptr %f, double %x, double %y) {
  bb0:
    %Sy_tmp0 = getelementptr i64, ptr %f, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i32 0
    %Sy_accum_ptr_4 = load ptr, ptr %Sy_tmp1
    %Sy_apply_cast_5 = bitcast double %x to i64
    %Sy_apply_cast_6 = bitcast double %y to i64
    %Sy_var0 = call i64 %Sy_accum_ptr_4(i64 %Sy_apply_cast_5, i64 %Sy_apply_cast_6, ptr %f, i64 0)
    ; nop
    ret i64 %Sy_var0
  }
  
  define i64 @syliTest_multi.add__i64__i64__i64_ret_i64(i64 %x, i64 %y, i64 %z) {
  bb0:
    ret i64 %x
  }
  
  define i64 @syliTest_multi.add__i64__f64__f64_ret_i64(i64 %x, double %y, double %z) {
  bb0:
    ret i64 %x
  }
  
  define i64 @__make_closure_accum.dispatch.66_ret_i64(i64 %Sy_x0, i64 %Sy_x1, ptr %Sy_clos, i64 %Sy_dp_id) {
  bb-1:
    %Sy_tmp0 = getelementptr i64, ptr %Sy_clos, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i64 1
    %Sy_val0 = load i64, ptr %Sy_tmp1
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
  
  define i64 @__partial_closure_accum.clos0_arg2_ret_i64(i64 %Sy_x0, i64 %Sy_x1, ptr %Sy_clos, i64 %Sy_dp_id) {
  bb0:
    %Sy_tmp0 = getelementptr i64, ptr %Sy_clos, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i64 1
    %Sy_p_clos = load ptr, ptr %Sy_tmp1
    %Sy_tmp2 = getelementptr i64, ptr %Sy_p_clos, i32 2
    %Sy_tmp3 = getelementptr i64, ptr %Sy_tmp2, i64 0
    %Sy_p_accum = load ptr, ptr %Sy_tmp3
    %Sy_rst = call i64 %Sy_p_accum(i64 %Sy_x0, i64 %Sy_x1, ptr %Sy_p_clos, i64 %Sy_dp_id)
    ret i64 %Sy_rst
  }
  
  define i64 @__partial_closure_accum.dispatch.clos0_arg2_ret_i64(i64 %Sy_x0, i64 %Sy_x1, ptr %Sy_clos, i64 %Sy_dp_id) {
  bb0:
    %Sy_tmp0 = getelementptr i64, ptr %Sy_clos, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i64 1
    %Sy_dp_clos = load i64, ptr %Sy_tmp1
    %Sy_accum_dp_id = add i64 %Sy_dp_id, %Sy_dp_clos
    %Sy_tmp2 = getelementptr i64, ptr %Sy_clos, i32 2
    %Sy_tmp3 = getelementptr i64, ptr %Sy_tmp2, i64 2
    %Sy_p_clos = load ptr, ptr %Sy_tmp3
    %Sy_tmp4 = getelementptr i64, ptr %Sy_p_clos, i32 2
    %Sy_tmp5 = getelementptr i64, ptr %Sy_tmp4, i64 0
    %Sy_p_accum = load ptr, ptr %Sy_tmp5
    %Sy_rst = call i64 %Sy_p_accum(i64 %Sy_x0, i64 %Sy_x1, ptr %Sy_p_clos, i64 %Sy_accum_dp_id)
    ret i64 %Sy_rst
  }
  
  define i64 @__wrapper.syliTest_multi.add.i64_f64_f64_ret_i64(i64 %Sy_x0, i64 %Sy_x1, i64 %Sy_x2) {
  bb0:
    %Sy_s1 = bitcast i64 %Sy_x1 to double
    %Sy_s2 = bitcast i64 %Sy_x2 to double
    %Sy_rst = call i64 @syliTest_multi.add__i64__f64__f64_ret_i64(i64 %Sy_x0, double %Sy_s1, double %Sy_s2)
    ret i64 %Sy_rst
  }
  
  define i64 @__wrapper.syliTest_multi.add.i64_i64_i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1, i64 %Sy_x2) {
  bb0:
    %Sy_rst = call i64 @syliTest_multi.add__i64__i64__i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1, i64 %Sy_x2)
    ret i64 %Sy_rst
  }
  

  $ clang -c test_multi.ll -o /dev/null 2>/dev/null

