  $ cat >test_e2e_print.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > type person = { name: int64; age: int64 }
  > fn main () =
  >     let record = { name = 10; age = 30 }
  >     syli_print_i64(record.age)
  > EOF
  $ dune exec sylic -- cir test_e2e_print.sy
  module Test_e2e_print :
  ffi_external_functions:
  extern fn syli_print_i64(i64) -> void
  
  
  functions:
  public fn __init.Test_e2e_print() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_e2e_print.main() -> void:
    entry: bb0
  
    bb0:
      %Sy_var0:obj = object_create{size=2:i64 record{fields=2 tag=0 [i64; i64]}}
      obj_set(%Sy_var0:obj, 0:i64, 10:i64):i64
      obj_set(%Sy_var0:obj, 1:i64, 30:i64):i64
      %Sy_var1:i64 = obj_get(%Sy_var0:obj, 1:i64):i64
      %Sy_var2:void = #call_direct syliTest_e2e_print.syli_print_i64 (%Sy_var1:i64)
      return
  end
  
  end
  $ dune exec sylic -- llvm test_e2e_print.sy > test_e2e_print.ll
  $ cat test_e2e_print.ll
  declare void @syli_rt_gc_cycle()
  declare void @syli_rt_object_check_release(ptr)
  declare void @syli_rt_object_decr(ptr)
  declare ptr @syli_rt_rc_alloc_object(i64, i32, i64)
  declare void @syli_print_i64(i64)
  
  define i32 @syli_startup_program(i32 %argc, ptr %argv) {
  bb0:
    call void @syli_modules_init()
    call void @syliTest_e2e_print.main()
    ret i32 0
  }
  
  define void @syli_modules_init() {
  bb0:
    call void @__init.Test_e2e_print()
    ret void
  }
  
  define void @__init.Test_e2e_print() {
  bb0:
    ret void
  }
  
  define void @syliTest_e2e_print.main() {
  bb0:
    call void @syli_rt_gc_cycle()
    %Sy_var0 = call ptr @syli_rt_rc_alloc_object(i64 2305843009213693954, i32 1, i64 2)
    ; nop
    %Sy_tmp0 = getelementptr i64, ptr %Sy_var0, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i64 0
    store i64 10, ptr %Sy_tmp1
    %Sy_tmp2 = getelementptr i64, ptr %Sy_var0, i32 2
    %Sy_tmp3 = getelementptr i64, ptr %Sy_tmp2, i64 1
    store i64 30, ptr %Sy_tmp3
    %Sy_tmp4 = getelementptr i64, ptr %Sy_var0, i32 2
    %Sy_tmp5 = getelementptr i64, ptr %Sy_tmp4, i64 1
    %Sy_var1 = load i64, ptr %Sy_tmp5
    call void @syli_rt_object_decr(ptr %Sy_var0)
    call void @syli_rt_object_check_release(ptr %Sy_var0)
    call void @syli_print_i64(i64 %Sy_var1)
    ret void
  }
  


  $ clang -c test_e2e_print.ll -o /dev/null 2>/dev/null
