  $ cat >test_file.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > let id x = x
  > let apply_twice f x = f (f x)
  > fn main () =
  >   let result_1 = apply_twice id 10
  >   syli_print_i64 result_1
  > EOF
  $ dune exec sylic -- core test_file.sy > test_file.core
  $ dune exec sylic -- cir test_file.sy > test_file.ir
  $ dune exec sylic -- llvm test_file.sy > test_file.ll

  $ cat test_file.core
  module Test_file
  let syliTest_file.id = fun (x) : 'a53 ->
      x : 'a53
  
  let syliTest_file.apply_twice = fun (f, x) : 'a61 ->
      f(f(x : 'a61) : 'a61) : 'a61
  
  let syliTest_file.main = fun () : unit ->
      {
        let syliTest_file.main__result_1 = syliTest_file.apply_twice(syliTest_file.id : (i64) -> i64, 10 : i64) : i64
        syliTest_file.syli_print_i64(syliTest_file.main__result_1 : i64) : unit
      }
  

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
      %Sy_var0:(i64 -> i64) = #make_closure {syliTest_file.id} () ()
      %Sy_var1:i64 = #call_direct syliTest_file.apply_twice__fn_i64_i64__i64_ret_i64 (%Sy_var0:(i64 -> i64), 10:i64)
      %Sy_var2:void = #call_direct syliTest_file.syli_print_i64 (%Sy_var1:i64)
      return
  end
  
  public fn syliTest_file.apply_twice__fn_i64_i64__i64_ret_i64(%f:(i64 -> i64), %x:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = #call_apply {%f:(i64 -> i64)}  (%x:i64)
      %Sy_var1:i64 = #call_apply {%f:(i64 -> i64)}  (%Sy_var0:i64)
      return %Sy_var1:i64
  end
  
  public fn syliTest_file.id__i64_ret_i64(%x:i64) -> i64:
    entry: bb0
  
    bb0:
  
      return %x:i64
  end
  
  end

  $ cat test_file.ll
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
    %Sy_var0 = call ptr @syli_rt_rc_alloc_object(i64 2305843009213693953, i32 1, i32 1)
    ; nop
    %Sy_accum_fn_0 = bitcast ptr @__make_closure_accum.syliTest_file.id.54_ret_i64 to ptr
    %Sy_tmp0 = getelementptr i64, ptr %Sy_var0, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i32 0
    store ptr %Sy_accum_fn_0, ptr %Sy_tmp1
    ; nop
    %Sy_var1 = call i64 @syliTest_file.apply_twice__fn_i64_i64__i64_ret_i64(ptr %Sy_var0, i64 10)
    call void @syli_rt_object_decr(ptr %Sy_var0)
    call void @syli_rt_object_check_release(ptr %Sy_var0)
    call void @syli_print_i64(i64 %Sy_var1)
    ret void
  }
  
  define i64 @syliTest_file.apply_twice__fn_i64_i64__i64_ret_i64(ptr %f, i64 %x) {
  bb0:
    %Sy_tmp0 = getelementptr i64, ptr %f, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i32 0
    %Sy_accum_ptr_1 = load ptr, ptr %Sy_tmp1
    %Sy_var0 = call i64 %Sy_accum_ptr_1(i64 %x, ptr %f, i64 0)
    ; nop
    %Sy_tmp2 = getelementptr i64, ptr %f, i32 2
    %Sy_tmp3 = getelementptr i64, ptr %Sy_tmp2, i32 0
    %Sy_accum_ptr_2 = load ptr, ptr %Sy_tmp3
    %Sy_var1 = call i64 %Sy_accum_ptr_2(i64 %Sy_var0, ptr %f, i64 0)
    ; nop
    ret i64 %Sy_var1
  }
  
  define i64 @syliTest_file.id__i64_ret_i64(i64 %x) {
  bb0:
    ret i64 %x
  }
  
  define i64 @__make_closure_accum.syliTest_file.id.54_ret_i64(i64 %Sy_x0, ptr %Sy_clos, i64 %Sy_dp_id) {
  bb0:
    %Sy_rst = call i64 @__wrapper.syliTest_file.id.i64_ret_i64(i64 %Sy_x0)
    ret i64 %Sy_rst
  }
  
  define i64 @__wrapper.syliTest_file.id.i64_ret_i64(i64 %Sy_x0) {
  bb0:
    %Sy_rst = call i64 @syliTest_file.id__i64_ret_i64(i64 %Sy_x0)
    ret i64 %Sy_rst
  }
  
  $ clang -c test_file.ll -o /dev/null 2>/dev/null
