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
  

  $ clang -O1 -S -emit-llvm --target=x86_64-pc-linux-gnu test_multi.ll -o test_multi_opt.ll
  warning: overriding the module target triple with x86_64-pc-linux-gnu [-Woverride-module]
  1 warning generated.
  $ cat test_multi_opt.ll
  ; ModuleID = 'test_multi.ll'
  source_filename = "test_multi.ll"
  target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
  target triple = "x86_64-pc-linux-gnu"
  
  declare void @syli_rt_gc_cycle() local_unnamed_addr
  
  declare void @syli_rt_object_check_release(ptr) local_unnamed_addr
  
  declare void @syli_rt_object_decr(ptr) local_unnamed_addr
  
  declare ptr @syli_rt_rc_alloc_object(i64, i32, i32) local_unnamed_addr
  
  define noundef i32 @syli_startup_program(i32 %argc, ptr nocapture readnone %argv) local_unnamed_addr {
  bb0:
    tail call void @syli_rt_gc_cycle()
    %Sy_var0.i = tail call ptr @syli_rt_rc_alloc_object(i64 2305843009213693954, i32 1, i32 2)
    %Sy_tmp0.i = getelementptr i64, ptr %Sy_var0.i, i64 2
    store ptr @__make_closure_accum.dispatch.66_ret_i64, ptr %Sy_tmp0.i, align 8
    %Sy_tmp3.i = getelementptr i64, ptr %Sy_var0.i, i64 3
    store i64 1, ptr %Sy_tmp3.i, align 4
    tail call void @syli_rt_gc_cycle()
    %Sy_var3.i = tail call ptr @syli_rt_rc_alloc_object(i64 4179340454199820354, i32 1, i32 2)
    %Sy_tmp10.i = getelementptr i64, ptr %Sy_var3.i, i64 2
    store ptr @__partial_closure_accum.clos0_arg2_ret_i64, ptr %Sy_tmp10.i, align 8
    %Sy_tmp13.i = getelementptr i64, ptr %Sy_var3.i, i64 3
    store ptr %Sy_var0.i, ptr %Sy_tmp13.i, align 8
    tail call void @syli_rt_object_decr(ptr %Sy_var0.i)
    tail call void @syli_rt_object_check_release(ptr %Sy_var0.i)
    %Sy_accum_ptr_3.i.i = load ptr, ptr %Sy_tmp10.i, align 8
    %Sy_var0.i.i = tail call i64 %Sy_accum_ptr_3.i.i(i64 3, i64 4, ptr %Sy_var3.i, i64 0)
    tail call void @syli_rt_object_decr(ptr %Sy_var3.i)
    tail call void @syli_rt_object_check_release(ptr %Sy_var3.i)
    ret i32 0
  }
  
  ; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
  define void @syli_modules_init() local_unnamed_addr #0 {
  bb0:
    ret void
  }
  
  ; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
  define void @__init.Test_multi() local_unnamed_addr #0 {
  bb0:
    ret void
  }
  
  define i64 @syliTest_multi.main() local_unnamed_addr {
  bb0:
    tail call void @syli_rt_gc_cycle()
    %Sy_var0 = tail call ptr @syli_rt_rc_alloc_object(i64 2305843009213693954, i32 1, i32 2)
    %Sy_tmp0 = getelementptr i64, ptr %Sy_var0, i64 2
    store ptr @__make_closure_accum.dispatch.66_ret_i64, ptr %Sy_tmp0, align 8
    %Sy_tmp3 = getelementptr i64, ptr %Sy_var0, i64 3
    store i64 1, ptr %Sy_tmp3, align 4
    tail call void @syli_rt_gc_cycle()
    %Sy_var3 = tail call ptr @syli_rt_rc_alloc_object(i64 4179340454199820354, i32 1, i32 2)
    %Sy_tmp10 = getelementptr i64, ptr %Sy_var3, i64 2
    store ptr @__partial_closure_accum.clos0_arg2_ret_i64, ptr %Sy_tmp10, align 8
    %Sy_tmp13 = getelementptr i64, ptr %Sy_var3, i64 3
    store ptr %Sy_var0, ptr %Sy_tmp13, align 8
    tail call void @syli_rt_object_decr(ptr %Sy_var0)
    tail call void @syli_rt_object_check_release(ptr %Sy_var0)
    %Sy_accum_ptr_3.i = load ptr, ptr %Sy_tmp10, align 8
    %Sy_var0.i = tail call i64 %Sy_accum_ptr_3.i(i64 3, i64 4, ptr %Sy_var3, i64 0)
    tail call void @syli_rt_object_decr(ptr %Sy_var3)
    tail call void @syli_rt_object_check_release(ptr %Sy_var3)
    ret i64 %Sy_var0.i
  }
  
  define i64 @syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64(ptr %f, i64 %x, i64 %y) local_unnamed_addr {
  bb0:
    %Sy_tmp0 = getelementptr i64, ptr %f, i64 2
    %Sy_accum_ptr_3 = load ptr, ptr %Sy_tmp0, align 8
    %Sy_var0 = tail call i64 %Sy_accum_ptr_3(i64 %x, i64 %y, ptr %f, i64 0)
    ret i64 %Sy_var0
  }
  
  define i64 @syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64(ptr %f, double %x, double %y) local_unnamed_addr {
  bb0:
    %Sy_tmp0 = getelementptr i64, ptr %f, i64 2
    %Sy_accum_ptr_4 = load ptr, ptr %Sy_tmp0, align 8
    %Sy_apply_cast_5 = bitcast double %x to i64
    %Sy_apply_cast_6 = bitcast double %y to i64
    %Sy_var0 = tail call i64 %Sy_accum_ptr_4(i64 %Sy_apply_cast_5, i64 %Sy_apply_cast_6, ptr %f, i64 0)
    ret i64 %Sy_var0
  }
  
  ; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
  define i64 @syliTest_multi.add__i64__i64__i64_ret_i64(i64 returned %x, i64 %y, i64 %z) local_unnamed_addr #0 {
  bb0:
    ret i64 %x
  }
  
  ; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
  define i64 @syliTest_multi.add__i64__f64__f64_ret_i64(i64 returned %x, double %y, double %z) local_unnamed_addr #0 {
  bb0:
    ret i64 %x
  }
  
  ; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read)
  define i64 @__make_closure_accum.dispatch.66_ret_i64(i64 %Sy_x0, i64 %Sy_x1, ptr nocapture readonly %Sy_clos, i64 %Sy_dp_id) #1 {
  bb-1:
    %Sy_tmp1 = getelementptr i64, ptr %Sy_clos, i64 3
    %Sy_val0 = load i64, ptr %Sy_tmp1, align 4
    ret i64 %Sy_val0
  }
  
  define i64 @__partial_closure_accum.clos0_arg2_ret_i64(i64 %Sy_x0, i64 %Sy_x1, ptr nocapture readonly %Sy_clos, i64 %Sy_dp_id) {
  bb0:
    %Sy_tmp1 = getelementptr i64, ptr %Sy_clos, i64 3
    %Sy_p_clos = load ptr, ptr %Sy_tmp1, align 8
    %Sy_tmp2 = getelementptr i64, ptr %Sy_p_clos, i64 2
    %Sy_p_accum = load ptr, ptr %Sy_tmp2, align 8
    %Sy_rst = tail call i64 %Sy_p_accum(i64 %Sy_x0, i64 %Sy_x1, ptr %Sy_p_clos, i64 %Sy_dp_id)
    ret i64 %Sy_rst
  }
  
  define i64 @__partial_closure_accum.dispatch.clos0_arg2_ret_i64(i64 %Sy_x0, i64 %Sy_x1, ptr nocapture readonly %Sy_clos, i64 %Sy_dp_id) local_unnamed_addr {
  bb0:
    %Sy_tmp1 = getelementptr i64, ptr %Sy_clos, i64 3
    %Sy_dp_clos = load i64, ptr %Sy_tmp1, align 4
    %Sy_accum_dp_id = add i64 %Sy_dp_clos, %Sy_dp_id
    %Sy_tmp3 = getelementptr i64, ptr %Sy_clos, i64 4
    %Sy_p_clos = load ptr, ptr %Sy_tmp3, align 8
    %Sy_tmp4 = getelementptr i64, ptr %Sy_p_clos, i64 2
    %Sy_p_accum = load ptr, ptr %Sy_tmp4, align 8
    %Sy_rst = tail call i64 %Sy_p_accum(i64 %Sy_x0, i64 %Sy_x1, ptr %Sy_p_clos, i64 %Sy_accum_dp_id)
    ret i64 %Sy_rst
  }
  
  ; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
  define i64 @__wrapper.syliTest_multi.add.i64_f64_f64_ret_i64(i64 returned %Sy_x0, i64 %Sy_x1, i64 %Sy_x2) local_unnamed_addr #0 {
  bb0:
    ret i64 %Sy_x0
  }
  
  ; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
  define i64 @__wrapper.syliTest_multi.add.i64_i64_i64_ret_i64(i64 returned %Sy_x0, i64 %Sy_x1, i64 %Sy_x2) local_unnamed_addr #0 {
  bb0:
    ret i64 %Sy_x0
  }
  
  attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) }
  attributes #1 = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read) }

  $ clang -O3 -S -emit-llvm --target=x86_64-pc-linux-gnu test_multi_opt.ll -o test_multi_opt3.ll
  $ cat test_multi_opt3.ll
  ; ModuleID = 'test_multi_opt.ll'
  source_filename = "test_multi.ll"
  target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
  target triple = "x86_64-pc-linux-gnu"
  
  declare void @syli_rt_gc_cycle() local_unnamed_addr
  
  declare void @syli_rt_object_check_release(ptr) local_unnamed_addr
  
  declare void @syli_rt_object_decr(ptr) local_unnamed_addr
  
  declare ptr @syli_rt_rc_alloc_object(i64, i32, i32) local_unnamed_addr
  
  define noundef i32 @syli_startup_program(i32 %argc, ptr nocapture readnone %argv) local_unnamed_addr {
  bb0:
    tail call void @syli_rt_gc_cycle()
    %Sy_var0.i = tail call ptr @syli_rt_rc_alloc_object(i64 2305843009213693954, i32 1, i32 2)
    %Sy_tmp0.i = getelementptr i64, ptr %Sy_var0.i, i64 2
    store ptr @__make_closure_accum.dispatch.66_ret_i64, ptr %Sy_tmp0.i, align 8
    %Sy_tmp3.i = getelementptr i64, ptr %Sy_var0.i, i64 3
    store i64 1, ptr %Sy_tmp3.i, align 4
    tail call void @syli_rt_gc_cycle()
    %Sy_var3.i = tail call ptr @syli_rt_rc_alloc_object(i64 4179340454199820354, i32 1, i32 2)
    %Sy_tmp10.i = getelementptr i64, ptr %Sy_var3.i, i64 2
    store ptr @__partial_closure_accum.clos0_arg2_ret_i64, ptr %Sy_tmp10.i, align 8
    %Sy_tmp13.i = getelementptr i64, ptr %Sy_var3.i, i64 3
    store ptr %Sy_var0.i, ptr %Sy_tmp13.i, align 8
    tail call void @syli_rt_object_decr(ptr %Sy_var0.i)
    tail call void @syli_rt_object_check_release(ptr %Sy_var0.i)
    %Sy_accum_ptr_3.i.i = load ptr, ptr %Sy_tmp10.i, align 8
    %Sy_var0.i.i = tail call i64 %Sy_accum_ptr_3.i.i(i64 3, i64 4, ptr %Sy_var3.i, i64 0)
    tail call void @syli_rt_object_decr(ptr %Sy_var3.i)
    tail call void @syli_rt_object_check_release(ptr %Sy_var3.i)
    ret i32 0
  }
  
  ; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
  define void @syli_modules_init() local_unnamed_addr #0 {
  bb0:
    ret void
  }
  
  ; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
  define void @__init.Test_multi() local_unnamed_addr #0 {
  bb0:
    ret void
  }
  
  define i64 @syliTest_multi.main() local_unnamed_addr {
  bb0:
    tail call void @syli_rt_gc_cycle()
    %Sy_var0 = tail call ptr @syli_rt_rc_alloc_object(i64 2305843009213693954, i32 1, i32 2)
    %Sy_tmp0 = getelementptr i64, ptr %Sy_var0, i64 2
    store ptr @__make_closure_accum.dispatch.66_ret_i64, ptr %Sy_tmp0, align 8
    %Sy_tmp3 = getelementptr i64, ptr %Sy_var0, i64 3
    store i64 1, ptr %Sy_tmp3, align 4
    tail call void @syli_rt_gc_cycle()
    %Sy_var3 = tail call ptr @syli_rt_rc_alloc_object(i64 4179340454199820354, i32 1, i32 2)
    %Sy_tmp10 = getelementptr i64, ptr %Sy_var3, i64 2
    store ptr @__partial_closure_accum.clos0_arg2_ret_i64, ptr %Sy_tmp10, align 8
    %Sy_tmp13 = getelementptr i64, ptr %Sy_var3, i64 3
    store ptr %Sy_var0, ptr %Sy_tmp13, align 8
    tail call void @syli_rt_object_decr(ptr %Sy_var0)
    tail call void @syli_rt_object_check_release(ptr %Sy_var0)
    %Sy_accum_ptr_3.i = load ptr, ptr %Sy_tmp10, align 8
    %Sy_var0.i = tail call i64 %Sy_accum_ptr_3.i(i64 3, i64 4, ptr %Sy_var3, i64 0)
    tail call void @syli_rt_object_decr(ptr %Sy_var3)
    tail call void @syli_rt_object_check_release(ptr %Sy_var3)
    ret i64 %Sy_var0.i
  }
  
  define i64 @syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64(ptr %f, i64 %x, i64 %y) local_unnamed_addr {
  bb0:
    %Sy_tmp0 = getelementptr i64, ptr %f, i64 2
    %Sy_accum_ptr_3 = load ptr, ptr %Sy_tmp0, align 8
    %Sy_var0 = tail call i64 %Sy_accum_ptr_3(i64 %x, i64 %y, ptr %f, i64 0)
    ret i64 %Sy_var0
  }
  
  define i64 @syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64(ptr %f, double %x, double %y) local_unnamed_addr {
  bb0:
    %Sy_tmp0 = getelementptr i64, ptr %f, i64 2
    %Sy_accum_ptr_4 = load ptr, ptr %Sy_tmp0, align 8
    %Sy_apply_cast_5 = bitcast double %x to i64
    %Sy_apply_cast_6 = bitcast double %y to i64
    %Sy_var0 = tail call i64 %Sy_accum_ptr_4(i64 %Sy_apply_cast_5, i64 %Sy_apply_cast_6, ptr %f, i64 0)
    ret i64 %Sy_var0
  }
  
  ; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
  define i64 @syliTest_multi.add__i64__i64__i64_ret_i64(i64 returned %x, i64 %y, i64 %z) local_unnamed_addr #0 {
  bb0:
    ret i64 %x
  }
  
  ; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
  define i64 @syliTest_multi.add__i64__f64__f64_ret_i64(i64 returned %x, double %y, double %z) local_unnamed_addr #0 {
  bb0:
    ret i64 %x
  }
  
  ; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read)
  define i64 @__make_closure_accum.dispatch.66_ret_i64(i64 %Sy_x0, i64 %Sy_x1, ptr nocapture readonly %Sy_clos, i64 %Sy_dp_id) #1 {
  bb-1:
    %Sy_tmp1 = getelementptr i64, ptr %Sy_clos, i64 3
    %Sy_val0 = load i64, ptr %Sy_tmp1, align 4
    ret i64 %Sy_val0
  }
  
  define i64 @__partial_closure_accum.clos0_arg2_ret_i64(i64 %Sy_x0, i64 %Sy_x1, ptr nocapture readonly %Sy_clos, i64 %Sy_dp_id) {
  bb0:
    %Sy_tmp1 = getelementptr i64, ptr %Sy_clos, i64 3
    %Sy_p_clos = load ptr, ptr %Sy_tmp1, align 8
    %Sy_tmp2 = getelementptr i64, ptr %Sy_p_clos, i64 2
    %Sy_p_accum = load ptr, ptr %Sy_tmp2, align 8
    %Sy_rst = tail call i64 %Sy_p_accum(i64 %Sy_x0, i64 %Sy_x1, ptr %Sy_p_clos, i64 %Sy_dp_id)
    ret i64 %Sy_rst
  }
  
  define i64 @__partial_closure_accum.dispatch.clos0_arg2_ret_i64(i64 %Sy_x0, i64 %Sy_x1, ptr nocapture readonly %Sy_clos, i64 %Sy_dp_id) local_unnamed_addr {
  bb0:
    %Sy_tmp1 = getelementptr i64, ptr %Sy_clos, i64 3
    %Sy_dp_clos = load i64, ptr %Sy_tmp1, align 4
    %Sy_accum_dp_id = add i64 %Sy_dp_clos, %Sy_dp_id
    %Sy_tmp3 = getelementptr i64, ptr %Sy_clos, i64 4
    %Sy_p_clos = load ptr, ptr %Sy_tmp3, align 8
    %Sy_tmp4 = getelementptr i64, ptr %Sy_p_clos, i64 2
    %Sy_p_accum = load ptr, ptr %Sy_tmp4, align 8
    %Sy_rst = tail call i64 %Sy_p_accum(i64 %Sy_x0, i64 %Sy_x1, ptr %Sy_p_clos, i64 %Sy_accum_dp_id)
    ret i64 %Sy_rst
  }
  
  ; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
  define i64 @__wrapper.syliTest_multi.add.i64_f64_f64_ret_i64(i64 returned %Sy_x0, i64 %Sy_x1, i64 %Sy_x2) local_unnamed_addr #0 {
  bb0:
    ret i64 %Sy_x0
  }
  
  ; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
  define i64 @__wrapper.syliTest_multi.add.i64_i64_i64_ret_i64(i64 returned %Sy_x0, i64 %Sy_x1, i64 %Sy_x2) local_unnamed_addr #0 {
  bb0:
    ret i64 %Sy_x0
  }
  
  attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) }
  attributes #1 = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read) }


  $ clang -O3 -S --target=x86_64-pc-linux-gnu test_multi_opt3.ll
  $ cat test_multi_opt3.s
  	.text
  	.file	"test_multi.ll"
  	.globl	syli_startup_program            # -- Begin function syli_startup_program
  	.p2align	4, 0x90
  	.type	syli_startup_program,@function
  syli_startup_program:                   # @syli_startup_program
  	.cfi_startproc
  # %bb.0:                                # %bb0
  	pushq	%r14
  	.cfi_def_cfa_offset 16
  	pushq	%rbx
  	.cfi_def_cfa_offset 24
  	pushq	%rax
  	.cfi_def_cfa_offset 32
  	.cfi_offset %rbx, -24
  	.cfi_offset %r14, -16
  	callq	syli_rt_gc_cycle@PLT
  	movabsq	$2305843009213693954, %rdi      # imm = 0x2000000000000002
  	movl	$1, %esi
  	movl	$2, %edx
  	callq	syli_rt_rc_alloc_object@PLT
  	movq	%rax, %rbx
  	movq	__make_closure_accum.dispatch.66_ret_i64@GOTPCREL(%rip), %rax
  	movq	%rax, 16(%rbx)
  	movq	$1, 24(%rbx)
  	callq	syli_rt_gc_cycle@PLT
  	movabsq	$4179340454199820354, %rdi      # imm = 0x3A00000000000042
  	movl	$1, %esi
  	movl	$2, %edx
  	callq	syli_rt_rc_alloc_object@PLT
  	movq	%rax, %r14
  	movq	__partial_closure_accum.clos0_arg2_ret_i64@GOTPCREL(%rip), %rax
  	movq	%rax, 16(%r14)
  	movq	%rbx, 24(%r14)
  	movq	%rbx, %rdi
  	callq	syli_rt_object_decr@PLT
  	movq	%rbx, %rdi
  	callq	syli_rt_object_check_release@PLT
  	movl	$3, %edi
  	movl	$4, %esi
  	movq	%r14, %rdx
  	xorl	%ecx, %ecx
  	callq	*16(%r14)
  	movq	%r14, %rdi
  	callq	syli_rt_object_decr@PLT
  	movq	%r14, %rdi
  	callq	syli_rt_object_check_release@PLT
  	xorl	%eax, %eax
  	addq	$8, %rsp
  	.cfi_def_cfa_offset 24
  	popq	%rbx
  	.cfi_def_cfa_offset 16
  	popq	%r14
  	.cfi_def_cfa_offset 8
  	retq
  .Lfunc_end0:
  	.size	syli_startup_program, .Lfunc_end0-syli_startup_program
  	.cfi_endproc
                                          # -- End function
  	.globl	syli_modules_init               # -- Begin function syli_modules_init
  	.p2align	4, 0x90
  	.type	syli_modules_init,@function
  syli_modules_init:                      # @syli_modules_init
  # %bb.0:                                # %bb0
  	retq
  .Lfunc_end1:
  	.size	syli_modules_init, .Lfunc_end1-syli_modules_init
                                          # -- End function
  	.globl	__init.Test_multi               # -- Begin function __init.Test_multi
  	.p2align	4, 0x90
  	.type	__init.Test_multi,@function
  __init.Test_multi:                      # @__init.Test_multi
  # %bb.0:                                # %bb0
  	retq
  .Lfunc_end2:
  	.size	__init.Test_multi, .Lfunc_end2-__init.Test_multi
                                          # -- End function
  	.globl	syliTest_multi.main             # -- Begin function syliTest_multi.main
  	.p2align	4, 0x90
  	.type	syliTest_multi.main,@function
  syliTest_multi.main:                    # @syliTest_multi.main
  	.cfi_startproc
  # %bb.0:                                # %bb0
  	pushq	%r14
  	.cfi_def_cfa_offset 16
  	pushq	%rbx
  	.cfi_def_cfa_offset 24
  	pushq	%rax
  	.cfi_def_cfa_offset 32
  	.cfi_offset %rbx, -24
  	.cfi_offset %r14, -16
  	callq	syli_rt_gc_cycle@PLT
  	movabsq	$2305843009213693954, %rdi      # imm = 0x2000000000000002
  	movl	$1, %esi
  	movl	$2, %edx
  	callq	syli_rt_rc_alloc_object@PLT
  	movq	%rax, %rbx
  	movq	__make_closure_accum.dispatch.66_ret_i64@GOTPCREL(%rip), %rax
  	movq	%rax, 16(%rbx)
  	movq	$1, 24(%rbx)
  	callq	syli_rt_gc_cycle@PLT
  	movabsq	$4179340454199820354, %rdi      # imm = 0x3A00000000000042
  	movl	$1, %esi
  	movl	$2, %edx
  	callq	syli_rt_rc_alloc_object@PLT
  	movq	%rax, %r14
  	movq	__partial_closure_accum.clos0_arg2_ret_i64@GOTPCREL(%rip), %rax
  	movq	%rax, 16(%r14)
  	movq	%rbx, 24(%r14)
  	movq	%rbx, %rdi
  	callq	syli_rt_object_decr@PLT
  	movq	%rbx, %rdi
  	callq	syli_rt_object_check_release@PLT
  	movl	$3, %edi
  	movl	$4, %esi
  	movq	%r14, %rdx
  	xorl	%ecx, %ecx
  	callq	*16(%r14)
  	movq	%rax, %rbx
  	movq	%r14, %rdi
  	callq	syli_rt_object_decr@PLT
  	movq	%r14, %rdi
  	callq	syli_rt_object_check_release@PLT
  	movq	%rbx, %rax
  	addq	$8, %rsp
  	.cfi_def_cfa_offset 24
  	popq	%rbx
  	.cfi_def_cfa_offset 16
  	popq	%r14
  	.cfi_def_cfa_offset 8
  	retq
  .Lfunc_end3:
  	.size	syliTest_multi.main, .Lfunc_end3-syliTest_multi.main
  	.cfi_endproc
                                          # -- End function
  	.globl	syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64 # -- Begin function syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64
  	.p2align	4, 0x90
  	.type	syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64,@function
  syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64: # @syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64
  	.cfi_startproc
  # %bb.0:                                # %bb0
  	movq	%rdi, %rax
  	movq	16(%rdi), %r8
  	movq	%rsi, %rdi
  	movq	%rdx, %rsi
  	movq	%rax, %rdx
  	xorl	%ecx, %ecx
  	jmpq	*%r8                            # TAILCALL
  .Lfunc_end4:
  	.size	syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64, .Lfunc_end4-syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64
  	.cfi_endproc
                                          # -- End function
  	.globl	syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64 # -- Begin function syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64
  	.p2align	4, 0x90
  	.type	syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64,@function
  syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64: # @syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64
  	.cfi_startproc
  # %bb.0:                                # %bb0
  	movq	%rdi, %rdx
  	movq	16(%rdi), %rax
  	movq	%xmm0, %rdi
  	movq	%xmm1, %rsi
  	xorl	%ecx, %ecx
  	jmpq	*%rax                           # TAILCALL
  .Lfunc_end5:
  	.size	syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64, .Lfunc_end5-syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64
  	.cfi_endproc
                                          # -- End function
  	.globl	syliTest_multi.add__i64__i64__i64_ret_i64 # -- Begin function syliTest_multi.add__i64__i64__i64_ret_i64
  	.p2align	4, 0x90
  	.type	syliTest_multi.add__i64__i64__i64_ret_i64,@function
  syliTest_multi.add__i64__i64__i64_ret_i64: # @syliTest_multi.add__i64__i64__i64_ret_i64
  # %bb.0:                                # %bb0
  	movq	%rdi, %rax
  	retq
  .Lfunc_end6:
  	.size	syliTest_multi.add__i64__i64__i64_ret_i64, .Lfunc_end6-syliTest_multi.add__i64__i64__i64_ret_i64
                                          # -- End function
  	.globl	syliTest_multi.add__i64__f64__f64_ret_i64 # -- Begin function syliTest_multi.add__i64__f64__f64_ret_i64
  	.p2align	4, 0x90
  	.type	syliTest_multi.add__i64__f64__f64_ret_i64,@function
  syliTest_multi.add__i64__f64__f64_ret_i64: # @syliTest_multi.add__i64__f64__f64_ret_i64
  # %bb.0:                                # %bb0
  	movq	%rdi, %rax
  	retq
  .Lfunc_end7:
  	.size	syliTest_multi.add__i64__f64__f64_ret_i64, .Lfunc_end7-syliTest_multi.add__i64__f64__f64_ret_i64
                                          # -- End function
  	.globl	__make_closure_accum.dispatch.66_ret_i64 # -- Begin function __make_closure_accum.dispatch.66_ret_i64
  	.p2align	4, 0x90
  	.type	__make_closure_accum.dispatch.66_ret_i64,@function
  __make_closure_accum.dispatch.66_ret_i64: # @__make_closure_accum.dispatch.66_ret_i64
  # %bb.0:                                # %bb-1
  	movq	24(%rdx), %rax
  	retq
  .Lfunc_end8:
  	.size	__make_closure_accum.dispatch.66_ret_i64, .Lfunc_end8-__make_closure_accum.dispatch.66_ret_i64
                                          # -- End function
  	.globl	__partial_closure_accum.clos0_arg2_ret_i64 # -- Begin function __partial_closure_accum.clos0_arg2_ret_i64
  	.p2align	4, 0x90
  	.type	__partial_closure_accum.clos0_arg2_ret_i64,@function
  __partial_closure_accum.clos0_arg2_ret_i64: # @__partial_closure_accum.clos0_arg2_ret_i64
  	.cfi_startproc
  # %bb.0:                                # %bb0
  	movq	24(%rdx), %rdx
  	movq	16(%rdx), %rax
  	jmpq	*%rax                           # TAILCALL
  .Lfunc_end9:
  	.size	__partial_closure_accum.clos0_arg2_ret_i64, .Lfunc_end9-__partial_closure_accum.clos0_arg2_ret_i64
  	.cfi_endproc
                                          # -- End function
  	.globl	__partial_closure_accum.dispatch.clos0_arg2_ret_i64 # -- Begin function __partial_closure_accum.dispatch.clos0_arg2_ret_i64
  	.p2align	4, 0x90
  	.type	__partial_closure_accum.dispatch.clos0_arg2_ret_i64,@function
  __partial_closure_accum.dispatch.clos0_arg2_ret_i64: # @__partial_closure_accum.dispatch.clos0_arg2_ret_i64
  	.cfi_startproc
  # %bb.0:                                # %bb0
  	addq	24(%rdx), %rcx
  	movq	32(%rdx), %rdx
  	movq	16(%rdx), %rax
  	jmpq	*%rax                           # TAILCALL
  .Lfunc_end10:
  	.size	__partial_closure_accum.dispatch.clos0_arg2_ret_i64, .Lfunc_end10-__partial_closure_accum.dispatch.clos0_arg2_ret_i64
  	.cfi_endproc
                                          # -- End function
  	.globl	__wrapper.syliTest_multi.add.i64_f64_f64_ret_i64 # -- Begin function __wrapper.syliTest_multi.add.i64_f64_f64_ret_i64
  	.p2align	4, 0x90
  	.type	__wrapper.syliTest_multi.add.i64_f64_f64_ret_i64,@function
  __wrapper.syliTest_multi.add.i64_f64_f64_ret_i64: # @__wrapper.syliTest_multi.add.i64_f64_f64_ret_i64
  # %bb.0:                                # %bb0
  	movq	%rdi, %rax
  	retq
  .Lfunc_end11:
  	.size	__wrapper.syliTest_multi.add.i64_f64_f64_ret_i64, .Lfunc_end11-__wrapper.syliTest_multi.add.i64_f64_f64_ret_i64
                                          # -- End function
  	.globl	__wrapper.syliTest_multi.add.i64_i64_i64_ret_i64 # -- Begin function __wrapper.syliTest_multi.add.i64_i64_i64_ret_i64
  	.p2align	4, 0x90
  	.type	__wrapper.syliTest_multi.add.i64_i64_i64_ret_i64,@function
  __wrapper.syliTest_multi.add.i64_i64_i64_ret_i64: # @__wrapper.syliTest_multi.add.i64_i64_i64_ret_i64
  # %bb.0:                                # %bb0
  	movq	%rdi, %rax
  	retq
  .Lfunc_end12:
  	.size	__wrapper.syliTest_multi.add.i64_i64_i64_ret_i64, .Lfunc_end12-__wrapper.syliTest_multi.add.i64_i64_i64_ret_i64
                                          # -- End function
  	.section	".note.GNU-stack","",@progbits
  	.addrsig
  	.addrsig_sym __make_closure_accum.dispatch.66_ret_i64
  	.addrsig_sym __partial_closure_accum.clos0_arg2_ret_i64

