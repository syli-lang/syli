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

  $ dune exec sylic -- llvm test_file.sy
  declare void @syli_rt_gc_cycle()
  declare void @syli_rt_object_check_release(ptr)
  declare void @syli_rt_object_decr(ptr)
  declare ptr @syli_rt_rc_alloc_object(i64, i32, i32)
  declare void @syli_print_i64(i64)
  
  define i32 @syli_startup_program(i32 %argc, ptr %argv) {
  bb0:
    call void @syli_modules_init()
    call void @syliTest_file.main()
    ret i32 0
  }
  
  define void @syli_modules_init() {
  bb0:
    call void @__init.Test_file()
    ret void
  }
  
  define void @__init.Test_file() {
  bb0:
    ret void
  }
  
  define void @syliTest_file.main() {
  bb0:
    call void @syli_rt_gc_cycle()
    %Sy_var0 = call ptr @syli_rt_rc_alloc_object(i64 3602879701896462337, i32 1, i32 2)
    ; nop
    %Sy_accum_fn_0 = bitcast ptr @__make_closure_accum.syliTest_file.add.111_ret_i64 to ptr
    %Sy_tmp0 = getelementptr i64, ptr %Sy_var0, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i32 0
    store ptr %Sy_accum_fn_0, ptr %Sy_tmp1
    %Sy_tmp2 = getelementptr i64, ptr %Sy_var0, i32 2
    %Sy_tmp3 = getelementptr i64, ptr %Sy_tmp2, i32 1
    store i64 1, ptr %Sy_tmp3
    ; nop
    %Sy_var1 = call i64 @syliTest_file.choose(ptr %Sy_var0)
    call void @syli_rt_object_decr(ptr %Sy_var0)
    call void @syli_rt_object_check_release(ptr %Sy_var0)
    call void @syli_print_i64(i64 %Sy_var1)
    ret void
  }
  
  define i64 @syliTest_file.choose(ptr %g) {
  bb0:
    %Sy_var2 = alloca ptr
    call void @syli_rt_gc_cycle()
    %Sy_var0 = call ptr @syli_rt_rc_alloc_object(i64 3602879701896462337, i32 1, i32 2)
    ; nop
    %Sy_accum_fn_1 = bitcast ptr @__make_closure_accum.syliTest_file.sub.54_ret_i64 to ptr
    %Sy_tmp0 = getelementptr i64, ptr %Sy_var0, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i32 0
    store ptr %Sy_accum_fn_1, ptr %Sy_tmp1
    %Sy_tmp2 = getelementptr i64, ptr %Sy_var0, i32 2
    %Sy_tmp3 = getelementptr i64, ptr %Sy_tmp2, i32 1
    store i64 1, ptr %Sy_tmp3
    ; nop
    br i1 true, label %bb1, label %bb2
  bb2:
    store ptr %Sy_var0, ptr %Sy_var2
    call void @syli_rt_object_decr(ptr %Sy_var0)
    call void @syli_rt_object_check_release(ptr %Sy_var0)
    br label %bb3
  bb1:
    store ptr %g, ptr %Sy_var2
    br label %bb3
  bb3:
    %Sy_tmp4 = load ptr, ptr %Sy_var2
    %Sy_tmp5 = getelementptr i64, ptr %Sy_tmp4, i32 2
    %Sy_tmp6 = getelementptr i64, ptr %Sy_tmp5, i32 0
    %Sy_accum_ptr_2 = load ptr, ptr %Sy_tmp6
    %Sy_tmp7 = load ptr, ptr %Sy_var2
    %Sy_var3 = call i64 %Sy_accum_ptr_2(i64 2, ptr %Sy_tmp7, i64 0)
    %Sy_tmp8 = load ptr, ptr %Sy_var2
    call void @syli_rt_object_decr(ptr %Sy_tmp8)
    %Sy_tmp9 = load ptr, ptr %Sy_var2
    call void @syli_rt_object_check_release(ptr %Sy_tmp9)
    ; nop
    ret i64 %Sy_var3
  }
  
  define i64 @syliTest_file.sub__i64__i64_ret_i64(i64 %x, i64 %y) {
  bb0:
    %Sy_var0 = sub i64 %x, %y
    ret i64 %Sy_var0
  }
  
  define i64 @syliTest_file.add__i64__i64_ret_i64(i64 %x, i64 %y) {
  bb0:
    %Sy_var0 = add i64 %x, %y
    ret i64 %Sy_var0
  }
  
  define i64 @__make_closure_accum.syliTest_file.add.111_ret_i64(i64 %Sy_x0, ptr %Sy_clos, i64 %Sy_dp_id) {
  bb0:
    %Sy_tmp0 = getelementptr i64, ptr %Sy_clos, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i64 1
    %Sy_val0 = load i64, ptr %Sy_tmp1
    %Sy_rst = call i64 @__wrapper.syliTest_file.add.i64_i64_ret_i64(i64 %Sy_val0, i64 %Sy_x0)
    ret i64 %Sy_rst
  }
  
  define i64 @__make_closure_accum.syliTest_file.sub.54_ret_i64(i64 %Sy_x0, ptr %Sy_clos, i64 %Sy_dp_id) {
  bb0:
    %Sy_tmp0 = getelementptr i64, ptr %Sy_clos, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i64 1
    %Sy_val0 = load i64, ptr %Sy_tmp1
    %Sy_rst = call i64 @__wrapper.syliTest_file.sub.i64_i64_ret_i64(i64 %Sy_val0, i64 %Sy_x0)
    ret i64 %Sy_rst
  }
  
  define i64 @__wrapper.syliTest_file.add.i64_i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1) {
  bb0:
    %Sy_rst = call i64 @syliTest_file.add__i64__i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1)
    ret i64 %Sy_rst
  }
  
  define i64 @__wrapper.syliTest_file.sub.i64_i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1) {
  bb0:
    %Sy_rst = call i64 @syliTest_file.sub__i64__i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1)
    ret i64 %Sy_rst
  }
  

