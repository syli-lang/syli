Closure with free variables:
  $ cat >test_multi.sy <<EOF
  > let apply () =
  >   let free = 1
  >   let add x y = free + y
  >   let result = add 1 2
  >   result
  > EOF
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  let syliTest_multi.apply = fun () : i64 ->
      {
        let syliTest_multi.apply__free = 1 : i64
        let syliTest_multi.apply__add = fun (x, y) : i64 ->
            (syliTest_multi.apply__free : i64 + y : i64) : i64
        let syliTest_multi.apply__result = syliTest_multi.apply__add(1 : i64, 2 : i64) : i64
        syliTest_multi.apply__result : i64
      }
  

  $ dune exec sylic -- cir test_multi.sy
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
      %syliTest_multi.apply__free:i64 = cast(1:i64 as i64)
      %syliTest_multi.apply__add:(?41, i64 -> i64) = #make_closure {syliTest_multi.apply__add} (%syliTest_multi.apply__free:i64) ()
      %Sy_var0:i64 = #call_apply {%syliTest_multi.apply__add:(?41, i64 -> i64) as (i64, i64 -> i64)}  (1:i64, 2:i64)
      return %Sy_var0:i64
  end
  
  private fn syliTest_multi.apply__add__i64__i64__i64_ret_i64(%syliTest_multi.apply__free:i64, %x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %syliTest_multi.apply__free:i64 + %y:i64
      return %Sy_var0:i64
  end
  
  end
  $ dune exec sylic -- llvm test_multi.sy
  declare void @syli_rt_gc_cycle()
  declare ptr addrspace(1) @syli_rt_ownership_alloc_object(i64, i32, i32)
  declare void @syli_rt_ownership_decr(ptr addrspace(1))
  declare void @syli_rt_ownership_incr(ptr addrspace(1))
  
  define void @__init.Test_multi() gc "statepoint-example" {
  bb0:
    ret void
  }
  
  define i64 @syliTest_multi.apply() gc "statepoint-example" {
  bb0:
    call void @syli_rt_gc_cycle()
    %syliTest_multi.apply__add = call ptr addrspace(1) @syli_rt_ownership_alloc_object(i64 2377900603251621890, i32 1, i32 2)
    ; nop
    %Sy_accum_fn_0 = bitcast ptr @__make_closure_accum.syliTest_multi.apply__add.26_ret_i64 to ptr
    %Sy_tmp0 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %syliTest_multi.apply__add)
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp0, i32 0, i32 2, i32 0
    store ptr %Sy_accum_fn_0, ptr addrspace(1) %Sy_tmp1
    %Sy_tmp2 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %syliTest_multi.apply__add)
    %Sy_tmp3 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp2, i32 0, i32 2, i32 1
    store i64 1, ptr addrspace(1) %Sy_tmp3
    ; nop
    %Sy_tmp4 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %syliTest_multi.apply__add)
    %Sy_tmp5 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp4, i32 0, i32 2, i32 0
    %Sy_accum_ptr_1 = load ptr, ptr addrspace(1) %Sy_tmp5
    %Sy_var0 = call i64 %Sy_accum_ptr_1(i64 1, i64 2, ptr addrspace(1) %syliTest_multi.apply__add, i64 0)
    ; nop
    ret i64 %Sy_var0
  }
  
  define i64 @syliTest_multi.apply__add__i64__i64__i64_ret_i64(i64 %syliTest_multi.apply__free, i64 %x, i64 %y) gc "statepoint-example" {
  bb0:
    %Sy_var0 = add i64 %syliTest_multi.apply__free, %y
    ret i64 %Sy_var0
  }
  
  define i64 @__make_closure_accum.syliTest_multi.apply__add.26_ret_i64(i64 %Sy_x0, i64 %Sy_x1, ptr addrspace(1) %Sy_clos, i64 %Sy_dp_id) gc "statepoint-example" {
  bb0:
    %Sy_tmp0 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_clos)
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp0, i32 0, i32 2, i64 1
    %Sy_val0 = load i64, ptr addrspace(1) %Sy_tmp1
    %Sy_tmp2 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_clos)
    %Sy_tmp3 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp2, i32 0, i32 2, i64 2
    %Sy_val1 = load i64, ptr addrspace(1) %Sy_tmp3
    call void @syli_inlinable_ownership_release(ptr addrspace(1) %Sy_clos)
    %Sy_rst = call i64 @__wrapper.syliTest_multi.apply__add.i64_i64_i64_ret_i64(i64 %Sy_val0, i64 %Sy_val1, i64 %Sy_x0, i64 %Sy_x1)
    ret i64 %Sy_rst
  }
  
  define i64 @__wrapper.syliTest_multi.apply__add.i64_i64_i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1, i64 %Sy_x2) gc "statepoint-example" {
  bb0:
    %Sy_rst = call i64 @syliTest_multi.apply__add__i64__i64__i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1, i64 %Sy_x2)
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
  

