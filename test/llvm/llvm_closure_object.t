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
  declare ptr addrspace(1) @syli_rt_ownership_alloc_object(i64, i32, i32)
  declare void @syli_rt_ownership_decr(ptr addrspace(1))
  declare void @syli_rt_ownership_incr(ptr addrspace(1))
  declare void @syli_rt_ownership_notify_mutation(ptr addrspace(1), ptr addrspace(1))
  declare ptr addrspace(1) @syli_rt_ownership_share(ptr addrspace(1))
  
  define void @__init.Test_multi() gc "statepoint-example" {
  bb0:
    ret void
  }
  
  define i64 @syliTest_multi.apply() gc "statepoint-example" {
  bb0:
    call void @syli_rt_gc_cycle()
    %Sy_var0 = call ptr addrspace(1) @syli_rt_ownership_alloc_object(i64 2377900603251621890, i32 1, i32 2)
    ; nop
    %Sy_accum_fn_0 = bitcast ptr @__make_closure_accum.syliTest_multi.add.40_ret_i64 to ptr
    %Sy_tmp0 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var0)
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp0, i32 0, i32 2, i32 0
    store ptr %Sy_accum_fn_0, ptr addrspace(1) %Sy_tmp1
    %Sy_tmp2 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var0)
    %Sy_tmp3 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp2, i32 0, i32 2, i32 1
    store i64 1, ptr addrspace(1) %Sy_tmp3
    ; nop
    call void @syli_rt_gc_cycle()
    %Sy_var1 = call ptr addrspace(1) @syli_rt_ownership_alloc_object(i64 4251398048237748291, i32 1, i32 3)
    ; nop
    %Sy_accum_fn_1 = bitcast ptr @__partial_closure_accum.clos1_arg1_ret_i64 to ptr
    %Sy_tmp4 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var1)
    %Sy_tmp5 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp4, i32 0, i32 2, i32 0
    store ptr %Sy_accum_fn_1, ptr addrspace(1) %Sy_tmp5
    %Sy_tmp6 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var1)
    %Sy_tmp7 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp6, i32 0, i32 2, i32 1
    %Sy_release_tmp_1 = load ptr addrspace(1), ptr addrspace(1) %Sy_tmp7
    call void @syli_inlinable_ownership_release(ptr addrspace(1) %Sy_release_tmp_1)
    %Sy_tmp_1 = call ptr addrspace(1) @syli_inlinable_ownership_own(ptr addrspace(1) %Sy_var0)
    %Sy_tmp8 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var1)
    %Sy_tmp9 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp8, i32 0, i32 2, i32 1
    store ptr addrspace(1) %Sy_tmp_1, ptr addrspace(1) %Sy_tmp9
    call void @syli_rt_ownership_notify_mutation(ptr addrspace(1) %Sy_var1, ptr addrspace(1) %Sy_tmp_1)
    %Sy_tmp10 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var1)
    %Sy_tmp11 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp10, i32 0, i32 2, i32 2
    store i64 2, ptr addrspace(1) %Sy_tmp11
    ; nop
    %Sy_tmp12 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var1)
    %Sy_tmp13 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp12, i32 0, i32 2, i32 0
    %Sy_accum_ptr_2 = load ptr, ptr addrspace(1) %Sy_tmp13
    %Sy_var2 = call i64 %Sy_accum_ptr_2(i64 3, ptr addrspace(1) %Sy_var1, i64 0)
    ; nop
    ret i64 %Sy_var2
  }
  
  define i64 @syliTest_multi.add__i64__i64__i64_ret_i64(i64 %x, i64 %y, i64 %z) gc "statepoint-example" {
  bb0:
    %Sy_var0 = add i64 %x, %y
    %Sy_var1 = add i64 %Sy_var0, %z
    ret i64 %Sy_var1
  }
  
  define i64 @__make_closure_accum.syliTest_multi.add.40_ret_i64(i64 %Sy_x0, i64 %Sy_x1, ptr addrspace(1) %Sy_clos, i64 %Sy_dp_id) gc "statepoint-example" {
  bb0:
    %Sy_tmp0 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_clos)
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp0, i32 0, i32 2, i64 1
    %Sy_val0 = load i64, ptr addrspace(1) %Sy_tmp1
    call void @syli_inlinable_ownership_release(ptr addrspace(1) %Sy_clos)
    %Sy_rst = call i64 @__wrapper.syliTest_multi.add.i64_i64_i64_ret_i64(i64 %Sy_val0, i64 %Sy_x0, i64 %Sy_x1)
    ret i64 %Sy_rst
  }
  
  define i64 @__partial_closure_accum.clos1_arg1_ret_i64(i64 %Sy_x0, ptr addrspace(1) %Sy_clos, i64 %Sy_dp_id) gc "statepoint-example" {
  bb0:
    %Sy_tmp0 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_clos)
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp0, i32 0, i32 2, i64 1
    %Sy_raw_tmp_2 = load ptr addrspace(1), ptr addrspace(1) %Sy_tmp1
    %Sy_p_clos = call ptr addrspace(1) @syli_rt_ownership_share(ptr addrspace(1) %Sy_raw_tmp_2)
    %Sy_tmp2 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_p_clos)
    %Sy_tmp3 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp2, i32 0, i32 2, i64 0
    %Sy_p_accum = load ptr, ptr addrspace(1) %Sy_tmp3
    %Sy_tmp4 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_clos)
    %Sy_tmp5 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp4, i32 0, i32 2, i64 2
    %Sy_val0 = load i64, ptr addrspace(1) %Sy_tmp5
    call void @syli_inlinable_ownership_release(ptr addrspace(1) %Sy_clos)
    %Sy_rst = call i64 %Sy_p_accum(i64 %Sy_val0, i64 %Sy_x0, ptr addrspace(1) %Sy_p_clos, i64 %Sy_dp_id)
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
  
Closure as an argument:
  $ cat >test_multi.sy <<EOF
  > let add x y = x + y
  > let apply f x y = f x y
  > let result = apply add 3 4
  > EOF
  $ dune exec sylic -- llvm test_multi.sy
  declare void @syli_rt_gc_cycle()
  declare ptr addrspace(1) @syli_rt_ownership_alloc_object(i64, i32, i32)
  declare void @syli_rt_ownership_decr(ptr addrspace(1))
  declare void @syli_rt_ownership_incr(ptr addrspace(1))
  
  @syliTest_multi.result = global i64 zeroinitializer
  
  define void @__init.Test_multi() gc "statepoint-example" {
  bb0:
    %__init_tmp_0 = call i64 @__init_global.syliTest_multi.result()
    store i64 %__init_tmp_0, ptr @syliTest_multi.result
    ret void
  }
  
  define i64 @__init_global.syliTest_multi.result() gc "statepoint-example" {
  bb0:
    call void @syli_rt_gc_cycle()
    %Sy_var0 = call ptr addrspace(1) @syli_rt_ownership_alloc_object(i64 2377900603251621889, i32 1, i32 1)
    ; nop
    %Sy_accum_fn_0 = bitcast ptr @__make_closure_accum.syliTest_multi.add.61_ret_i64 to ptr
    %Sy_tmp0 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var0)
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp0, i32 0, i32 2, i32 0
    store ptr %Sy_accum_fn_0, ptr addrspace(1) %Sy_tmp1
    ; nop
    %Sy_var1 = call i64 @syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64(ptr addrspace(1) %Sy_var0, i64 3, i64 4)
    ret i64 %Sy_var1
  }
  
  define i64 @syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64(ptr addrspace(1) %f, i64 %x, i64 %y) gc "statepoint-example" {
  bb0:
    %Sy_tmp0 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %f)
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp0, i32 0, i32 2, i32 0
    %Sy_accum_ptr_1 = load ptr, ptr addrspace(1) %Sy_tmp1
    %Sy_var0 = call i64 %Sy_accum_ptr_1(i64 %x, i64 %y, ptr addrspace(1) %f, i64 0)
    ; nop
    ret i64 %Sy_var0
  }
  
  define i64 @syliTest_multi.add__i64__i64_ret_i64(i64 %x, i64 %y) gc "statepoint-example" {
  bb0:
    %Sy_var0 = add i64 %x, %y
    ret i64 %Sy_var0
  }
  
  define i64 @__make_closure_accum.syliTest_multi.add.61_ret_i64(i64 %Sy_x0, i64 %Sy_x1, ptr addrspace(1) %Sy_clos, i64 %Sy_dp_id) gc "statepoint-example" {
  bb0:
    call void @syli_inlinable_ownership_release(ptr addrspace(1) %Sy_clos)
    %Sy_rst = call i64 @__wrapper.syliTest_multi.add.i64_i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1)
    ret i64 %Sy_rst
  }
  
  define i64 @__wrapper.syliTest_multi.add.i64_i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1) gc "statepoint-example" {
  bb0:
    %Sy_rst = call i64 @syliTest_multi.add__i64__i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1)
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
  
