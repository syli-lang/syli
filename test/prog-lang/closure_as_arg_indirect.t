  $ cat >test_file.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > let add x y = x + y
  > let sub x y = x - y
  > let choose g =
  >   let sub1 = sub 1
  >   let f = if true then g else sub1
  >   let result = f 2
  > fn main () =
  >   let add1 = add 1
  >   let result = choose add1
  >   syli_print_i64 result
  > EOF
  $ dune exec sylic -- core test_file.sy > test_file.core
  $ dune exec sylic -- cir test_file.sy > test_file.ir

  $ cat test_file.ir
  module Test_file :
  ffi_external_functions:
  extern fn syli_print_i64(i64) -> void
  
  
  functions:
  public fn __init.Test_file() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_file.main() -> void:
    entry: bb0
  
    bb0:
      %Sy_var0:(i64 -> i64) = #make_closure {syliTest_file.add} () ( captured_args=[1:i64])
      %Sy_var1:i64 = #call_direct syliTest_file.choose (%Sy_var0:(i64 -> i64))
      %Sy_var2:void = #call_direct syliTest_file.syli_print_i64 (%Sy_var1:i64)
      return
  end
  
  public fn syliTest_file.choose(%g:(i64 -> i64)) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:(i64 -> i64) = #make_closure {syliTest_file.sub} () ( captured_args=[1:i64])
      %Sy_var1:bool = cast(true:bool as bool)
      cond_br %Sy_var1:bool, bb1, bb2
  
    bb2:
      %Sy_var2:(i64 -> i64) = move(%Sy_var0:(i64 -> i64))
      goto bb3
  
    bb1:
      %Sy_var2:(i64 -> i64) = move(%g:(i64 -> i64))
      goto bb3
  
    bb3:
      %Sy_var3:i64 = #call_apply {%Sy_var2:(i64 -> i64)}  (2:i64)
      return %Sy_var3:i64
  end
  
  public fn syliTest_file.sub__i64__i64_ret_i64(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 - %y:i64
      return %Sy_var0:i64
  end
  
  public fn syliTest_file.add__i64__i64_ret_i64(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 + %y:i64
      return %Sy_var0:i64
  end
  
  end

  $ dune exec sylic -- cir test_file.sy
  module Test_file :
  ffi_external_functions:
  extern fn syli_print_i64(i64) -> void
  
  
  functions:
  public fn __init.Test_file() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_file.main() -> void:
    entry: bb0
  
    bb0:
      %Sy_var0:(i64 -> i64) = #make_closure {syliTest_file.add} () ( captured_args=[1:i64])
      %Sy_var1:i64 = #call_direct syliTest_file.choose (%Sy_var0:(i64 -> i64))
      %Sy_var2:void = #call_direct syliTest_file.syli_print_i64 (%Sy_var1:i64)
      return
  end
  
  public fn syliTest_file.choose(%g:(i64 -> i64)) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:(i64 -> i64) = #make_closure {syliTest_file.sub} () ( captured_args=[1:i64])
      %Sy_var1:bool = cast(true:bool as bool)
      cond_br %Sy_var1:bool, bb1, bb2
  
    bb2:
      %Sy_var2:(i64 -> i64) = move(%Sy_var0:(i64 -> i64))
      goto bb3
  
    bb1:
      %Sy_var2:(i64 -> i64) = move(%g:(i64 -> i64))
      goto bb3
  
    bb3:
      %Sy_var3:i64 = #call_apply {%Sy_var2:(i64 -> i64)}  (2:i64)
      return %Sy_var3:i64
  end
  
  public fn syliTest_file.sub__i64__i64_ret_i64(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 - %y:i64
      return %Sy_var0:i64
  end
  
  public fn syliTest_file.add__i64__i64_ret_i64(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 + %y:i64
      return %Sy_var0:i64
  end
  
  end

  $ dune exec sylic -- oir test_file.sy
  module Test_file :
  ffi_external_functions:
  extern fn syli_print_i64(i64) -> void
  
  
  functions:
  public fn __init.Test_file() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_file.main() -> void:
    entry: bb0
  
    bb0:
      gc_cycle
      %Sy_var0:obj{{card=2 [0:fn_ptr; 1:i64]} tag=0 unknow_cyclic} = object_create{size=2:i32}
      
      %Sy_accum_fn_0:fn_ptr = addr_fn(__make_closure_accum.syliTest_file.add.110_ret_i64)
      obj_set(%Sy_var0:obj_ptr, 0:i32, %Sy_accum_fn_0:fn_ptr):fn_ptr
      obj_set(%Sy_var0:obj_ptr, 1:i32, 1:i64):i64
      
      %Sy_var1:i64 = #call_direct syliTest_file.choose (@transfer %Sy_var0:obj_ptr)
      %Sy_var2:void = #call_direct syliTest_file.syli_print_i64 (%Sy_var1:i64)
      return
  end
  
  public fn syliTest_file.choose(%g:obj_ptr) -> i64:
    entry: bb0
  
    bb0:
      gc_cycle
      %Sy_var0:obj{{card=2 [0:fn_ptr; 1:i64]} tag=0 unknow_cyclic} = object_create{size=2:i32}
      
      %Sy_accum_fn_1:fn_ptr = addr_fn(__make_closure_accum.syliTest_file.sub.53_ret_i64)
      obj_set(%Sy_var0:obj_ptr, 0:i32, %Sy_accum_fn_1:fn_ptr):fn_ptr
      obj_set(%Sy_var0:obj_ptr, 1:i32, 1:i64):i64
      
      %Sy_var1:bool = cast(true:bool as bool)
      cond_br %Sy_var1:bool, bb1, bb2
  
    bb2:
      release(%g:obj_ptr)
      %Sy_var2:obj_ptr = move(%Sy_var0:obj_ptr)
      goto bb3
  
    bb1:
      release(%Sy_var0:obj_ptr)
      %Sy_var2:obj_ptr = move(%g:obj_ptr)
      goto bb3
  
    bb3:
      %Sy_accum_ptr_2:fn_ptr = obj_get(%Sy_var2:obj_ptr, 0:i32):fn_ptr
      %Sy_var3:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_2:fn_ptr)  (2:i64, @transfer %Sy_var2:obj_ptr, 0:i64)
      
      return %Sy_var3:i64
  end
  
  public fn syliTest_file.sub__i64__i64_ret_i64(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 - %y:i64
      return %Sy_var0:i64
  end
  
  public fn syliTest_file.add__i64__i64_ret_i64(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 + %y:i64
      return %Sy_var0:i64
  end
  
  private fn __make_closure_accum.syliTest_file.add.110_ret_i64(%Sy_x0:i64, %Sy_clos:obj_ptr, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_val0:i64 = obj_get(%Sy_clos:obj_ptr, 1:i64):i64
      release(%Sy_clos:obj_ptr)
      %Sy_rst:i64 = #call_direct __wrapper.syliTest_file.add.i64_i64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64)
      return %Sy_rst:i64
  end
  
  private fn __make_closure_accum.syliTest_file.sub.53_ret_i64(%Sy_x0:i64, %Sy_clos:obj_ptr, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_val0:i64 = obj_get(%Sy_clos:obj_ptr, 1:i64):i64
      release(%Sy_clos:obj_ptr)
      %Sy_rst:i64 = #call_direct __wrapper.syliTest_file.sub.i64_i64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64)
      return %Sy_rst:i64
  end
  
  private fn __wrapper.syliTest_file.add.i64_i64_ret_i64(%Sy_x0:i64, %Sy_x1:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_s0:i64 = cast(%Sy_x0:i64 as i64)
      %Sy_s1:i64 = cast(%Sy_x1:i64 as i64)
      %Sy_rst:i64 = #call_direct syliTest_file.add__i64__i64_ret_i64 (%Sy_s0:i64, %Sy_s1:i64)
      return %Sy_rst:i64
  end
  
  private fn __wrapper.syliTest_file.sub.i64_i64_ret_i64(%Sy_x0:i64, %Sy_x1:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_s0:i64 = cast(%Sy_x0:i64 as i64)
      %Sy_s1:i64 = cast(%Sy_x1:i64 as i64)
      %Sy_rst:i64 = #call_direct syliTest_file.sub__i64__i64_ret_i64 (%Sy_s0:i64, %Sy_s1:i64)
      return %Sy_rst:i64
  end
  
  end

  $ dune exec sylic -- llvm test_file.sy
  declare void @syli_print_i64(i64)
  declare void @syli_rt_gc_cycle()
  declare ptr addrspace(1) @syli_rt_ownership_alloc_object(i64, i32, i32)
  declare void @syli_rt_ownership_decr(ptr addrspace(1))
  declare void @syli_rt_ownership_incr(ptr addrspace(1))
  
  define i32 @syli_startup_program(i32 %argc, ptr %argv) gc "statepoint-example" {
  bb0:
    call void @syli_modules_init()
    call void @syliTest_file.main()
    ret i32 0
  }
  
  define void @syli_modules_init() gc "statepoint-example" {
  bb0:
    call void @__init.Test_file()
    ret void
  }
  
  define void @__init.Test_file() gc "statepoint-example" {
  bb0:
    ret void
  }
  
  define void @syliTest_file.main() gc "statepoint-example" {
  bb0:
    call void @syli_rt_gc_cycle()
    %Sy_var0 = call ptr addrspace(1) @syli_rt_ownership_alloc_object(i64 2377900603251621890, i32 1, i32 2)
    ; nop
    %Sy_accum_fn_0 = bitcast ptr @__make_closure_accum.syliTest_file.add.110_ret_i64 to ptr
    %Sy_tmp0 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var0)
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp0, i32 0, i32 2, i32 0
    store ptr %Sy_accum_fn_0, ptr addrspace(1) %Sy_tmp1
    %Sy_tmp2 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var0)
    %Sy_tmp3 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp2, i32 0, i32 2, i32 1
    store i64 1, ptr addrspace(1) %Sy_tmp3
    ; nop
    %Sy_var1 = call i64 @syliTest_file.choose(ptr addrspace(1) %Sy_var0)
    call void @syli_print_i64(i64 %Sy_var1)
    ret void
  }
  
  define i64 @syliTest_file.choose(ptr addrspace(1) %g) gc "statepoint-example" {
  bb0:
    %Sy_var2 = alloca ptr addrspace(1)
    call void @syli_rt_gc_cycle()
    %Sy_var0 = call ptr addrspace(1) @syli_rt_ownership_alloc_object(i64 2377900603251621890, i32 1, i32 2)
    ; nop
    %Sy_accum_fn_1 = bitcast ptr @__make_closure_accum.syliTest_file.sub.53_ret_i64 to ptr
    %Sy_tmp0 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var0)
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp0, i32 0, i32 2, i32 0
    store ptr %Sy_accum_fn_1, ptr addrspace(1) %Sy_tmp1
    %Sy_tmp2 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var0)
    %Sy_tmp3 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp2, i32 0, i32 2, i32 1
    store i64 1, ptr addrspace(1) %Sy_tmp3
    ; nop
    br i1 true, label %bb1, label %bb2
  bb2:
    call void @syli_inlinable_ownership_release(ptr addrspace(1) %g)
    store ptr addrspace(1) %Sy_var0, ptr %Sy_var2
    br label %bb3
  bb1:
    call void @syli_inlinable_ownership_release(ptr addrspace(1) %Sy_var0)
    store ptr addrspace(1) %g, ptr %Sy_var2
    br label %bb3
  bb3:
    %Sy_tmp4 = load ptr addrspace(1), ptr %Sy_var2
    %Sy_tmp5 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_tmp4)
    %Sy_tmp6 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp5, i32 0, i32 2, i32 0
    %Sy_accum_ptr_2 = load ptr, ptr addrspace(1) %Sy_tmp6
    %Sy_tmp7 = load ptr addrspace(1), ptr %Sy_var2
    %Sy_var3 = call i64 %Sy_accum_ptr_2(i64 2, ptr addrspace(1) %Sy_tmp7, i64 0)
    ; nop
    ret i64 %Sy_var3
  }
  
  define i64 @syliTest_file.sub__i64__i64_ret_i64(i64 %x, i64 %y) gc "statepoint-example" {
  bb0:
    %Sy_var0 = sub i64 %x, %y
    ret i64 %Sy_var0
  }
  
  define i64 @syliTest_file.add__i64__i64_ret_i64(i64 %x, i64 %y) gc "statepoint-example" {
  bb0:
    %Sy_var0 = add i64 %x, %y
    ret i64 %Sy_var0
  }
  
  define i64 @__make_closure_accum.syliTest_file.add.110_ret_i64(i64 %Sy_x0, ptr addrspace(1) %Sy_clos, i64 %Sy_dp_id) gc "statepoint-example" {
  bb0:
    %Sy_tmp0 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_clos)
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp0, i32 0, i32 2, i64 1
    %Sy_val0 = load i64, ptr addrspace(1) %Sy_tmp1
    call void @syli_inlinable_ownership_release(ptr addrspace(1) %Sy_clos)
    %Sy_rst = call i64 @__wrapper.syliTest_file.add.i64_i64_ret_i64(i64 %Sy_val0, i64 %Sy_x0)
    ret i64 %Sy_rst
  }
  
  define i64 @__make_closure_accum.syliTest_file.sub.53_ret_i64(i64 %Sy_x0, ptr addrspace(1) %Sy_clos, i64 %Sy_dp_id) gc "statepoint-example" {
  bb0:
    %Sy_tmp0 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_clos)
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp0, i32 0, i32 2, i64 1
    %Sy_val0 = load i64, ptr addrspace(1) %Sy_tmp1
    call void @syli_inlinable_ownership_release(ptr addrspace(1) %Sy_clos)
    %Sy_rst = call i64 @__wrapper.syliTest_file.sub.i64_i64_ret_i64(i64 %Sy_val0, i64 %Sy_x0)
    ret i64 %Sy_rst
  }
  
  define i64 @__wrapper.syliTest_file.add.i64_i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1) gc "statepoint-example" {
  bb0:
    %Sy_rst = call i64 @syliTest_file.add__i64__i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1)
    ret i64 %Sy_rst
  }
  
  define i64 @__wrapper.syliTest_file.sub.i64_i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1) gc "statepoint-example" {
  bb0:
    %Sy_rst = call i64 @syliTest_file.sub__i64__i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1)
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
  

