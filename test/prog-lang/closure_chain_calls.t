  $ cat >test_file.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > let add x y z = x + y + z
  > let apply () =
  >   let add1 = add 1
  >   let add1and2 = add1 2
  >   let result = add1and2 3
  > fn main () = 
  >   let result = apply ()
  >   syli_print_i64 result
  > EOF

  $ dune exec sylic -- core test_file.sy > test_file.core
  $ dune exec sylic -- cir_raw test_file.sy > test_file.ir
  $ dune exec sylic -- oir test_file.sy > test_file.oir
  $ dune exec sylic -- llvm test_file.sy > test_file.ll

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
      %Sy_var0:i64 = #call_direct syliTest_file.apply ()
      %Sy_var1:void = #call_direct syliTest_file.syli_print_i64 (%Sy_var0:i64)
      return
  end
  
  public fn syliTest_file.apply() -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:(i64, i64 -> i64) = #make_closure {syliTest_file.add} () ( captured_args=[1:i64])
      %Sy_var1:(i64 -> i64) = #partial_apply {%Sy_var0:(i64, i64 -> i64)} (2:i64)
      %Sy_var2:i64 = #call_apply {%Sy_var1:(i64 -> i64)}  (3:i64)
      return %Sy_var2:i64
  end
  
  public fn syliTest_file.add(%x:?79, %y:?79, %z:?79) -> ?79:
    entry: bb0
  
    bb0:
      %Sy_var0:?79 = %x:?79 + %y:?79
      %Sy_var1:?79 = %Sy_var0:?79 + %z:?79
      return %Sy_var1:?79
  end
  
  end
  $ cat test_file.core
  module Test_file
  let syliTest_file.add = fun (x, y, z) : 'a79 ->
      ((x : 'a79 + y : 'a79) : 'a79 + z : 'a79) : 'a79
  
  let syliTest_file.apply = fun () : i64 ->
      {
        let syliTest_file.apply__add1 = syliTest_file.add(1 : i64) : (i64, i64) -> i64
        let syliTest_file.apply__add1and2 = syliTest_file.apply__add1(2 : i64) : (i64) -> i64
        let syliTest_file.apply__result = syliTest_file.apply__add1and2(3 : i64) : i64
      }
  
  let syliTest_file.main = fun () : unit ->
      {
        let syliTest_file.main__result = syliTest_file.apply() : i64
        syliTest_file.syli_print_i64(syliTest_file.main__result : i64) : unit
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
      %Sy_var0:i64 = #call_direct syliTest_file.apply ()
      %Sy_var1:void = #call_direct syliTest_file.syli_print_i64 (%Sy_var0:i64)
      return
  end
  
  public fn syliTest_file.apply() -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:(i64, i64 -> i64) = #make_closure {syliTest_file.add} () ( captured_args=[1:i64])
      %Sy_var1:(i64 -> i64) = #partial_apply {%Sy_var0:(i64, i64 -> i64)} (2:i64)
      %Sy_var2:i64 = #call_apply {%Sy_var1:(i64 -> i64)}  (3:i64)
      return %Sy_var2:i64
  end
  
  public fn syliTest_file.add(%x:?79, %y:?79, %z:?79) -> ?79:
    entry: bb0
  
    bb0:
      %Sy_var0:?79 = %x:?79 + %y:?79
      %Sy_var1:?79 = %Sy_var0:?79 + %z:?79
      return %Sy_var1:?79
  end
  
  end

  $ cat test_file.oir
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
      %Sy_var0:i64 = #call_direct syliTest_file.apply ()
      %Sy_var1:void = #call_direct syliTest_file.syli_print_i64 (%Sy_var0:i64)
      return
  end
  
  public fn syliTest_file.apply() -> i64:
    entry: bb0
  
    bb0:
      gc_cycle
      %Sy_var0:*void = object_create{size=2:i32 record{fields=2 tag=0 [fn_ptr; i64]}}
      
      %Sy_accum_fn_0:fn_ptr = addr_fn(__make_closure_accum.syliTest_file.add.41_ret_i64)
      obj_set(%Sy_var0:*void, 0:i32, %Sy_accum_fn_0:fn_ptr):fn_ptr
      obj_set(%Sy_var0:*void, 1:i32, 1:i64):i64
      
      gc_cycle
      %Sy_var1:*void = object_create{size=3:i32 record{fields=3 tag=0 [fn_ptr; *void; i64]}}
      
      %Sy_accum_fn_1:fn_ptr = addr_fn(__partial_closure_accum.clos1_arg1_ret_i64)
      obj_set(%Sy_var1:*void, 0:i32, %Sy_accum_fn_1:fn_ptr):fn_ptr
      obj_set(%Sy_var1:*void, 1:i32, %Sy_var0:*void):*void
      rc_decr(%Sy_var0:*void)
      rc_check_release(%Sy_var0:*void)
      obj_set(%Sy_var1:*void, 2:i32, 2:i64):i64
      
      %Sy_accum_ptr_2:fn_ptr = obj_get(%Sy_var1:*void, 0:i32):fn_ptr
      %Sy_var2:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_2:fn_ptr)  (3:i64, %Sy_var1:*void, 0:i64)
      rc_decr(%Sy_var1:*void)
      rc_check_release(%Sy_var1:*void)
      
      return %Sy_var2:i64
  end
  
  public fn syliTest_file.add__i64__i64__i64_ret_i64(%x:i64, %y:i64, %z:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 + %y:i64
      %Sy_var1:i64 = %Sy_var0:i64 + %z:i64
      return %Sy_var1:i64
  end
  
  private fn __make_closure_accum.syliTest_file.add.41_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 1:i64):i64
      %Sy_rst:i64 = #call_direct __wrapper.syliTest_file.add.i64_i64_i64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64, %Sy_x1:i64)
      return %Sy_rst:i64
  end
  
  private fn __partial_closure_accum.clos1_arg1_ret_i64(%Sy_x0:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_p_clos:*void = obj_get(%Sy_clos:*void, 1:i64):*void
      %Sy_p_accum:fn_ptr = obj_get(%Sy_p_clos:*void, 0:i64):fn_ptr
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 2:i64):i64
      %Sy_rst:i64 = #call_direct_fn_ptr(%Sy_p_accum:fn_ptr)  (%Sy_val0:i64, %Sy_x0:i64, %Sy_p_clos:*void, %Sy_dp_id:i64)
      return %Sy_rst:i64
  end
  
  private fn __wrapper.syliTest_file.add.i64_i64_i64_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_x2:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_s0:i64 = cast(%Sy_x0:i64 as i64)
      %Sy_s1:i64 = cast(%Sy_x1:i64 as i64)
      %Sy_s2:i64 = cast(%Sy_x2:i64 as i64)
      %Sy_rst:i64 = #call_direct syliTest_file.add__i64__i64__i64_ret_i64 (%Sy_s0:i64, %Sy_s1:i64, %Sy_s2:i64)
      return %Sy_rst:i64
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
    %Sy_var0 = call i64 @syliTest_file.apply()
    call void @syli_print_i64(i64 %Sy_var0)
    ret void
  }
  
  define i64 @syliTest_file.apply() {
  bb0:
    call void @syli_rt_gc_cycle()
    %Sy_var0 = call ptr @syli_rt_rc_alloc_object(i64 2305843009213693954, i32 1, i32 2)
    ; nop
    %Sy_accum_fn_0 = bitcast ptr @__make_closure_accum.syliTest_file.add.41_ret_i64 to ptr
    %Sy_tmp0 = getelementptr { i64, i64, [0 x i64] }, ptr %Sy_var0, i32 0, i32 2, i32 0
    store ptr %Sy_accum_fn_0, ptr %Sy_tmp0
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr %Sy_var0, i32 0, i32 2, i32 1
    store i64 1, ptr %Sy_tmp1
    ; nop
    call void @syli_rt_gc_cycle()
    %Sy_var1 = call ptr @syli_rt_rc_alloc_object(i64 4179340454199820355, i32 1, i32 3)
    ; nop
    %Sy_accum_fn_1 = bitcast ptr @__partial_closure_accum.clos1_arg1_ret_i64 to ptr
    %Sy_tmp2 = getelementptr { i64, i64, [0 x i64] }, ptr %Sy_var1, i32 0, i32 2, i32 0
    store ptr %Sy_accum_fn_1, ptr %Sy_tmp2
    %Sy_tmp3 = getelementptr { i64, i64, [0 x i64] }, ptr %Sy_var1, i32 0, i32 2, i32 1
    store ptr %Sy_var0, ptr %Sy_tmp3
    call void @syli_rt_object_decr(ptr %Sy_var0)
    call void @syli_rt_object_check_release(ptr %Sy_var0)
    %Sy_tmp4 = getelementptr { i64, i64, [0 x i64] }, ptr %Sy_var1, i32 0, i32 2, i32 2
    store i64 2, ptr %Sy_tmp4
    ; nop
    %Sy_tmp5 = getelementptr { i64, i64, [0 x i64] }, ptr %Sy_var1, i32 0, i32 2, i32 0
    %Sy_accum_ptr_2 = load ptr, ptr %Sy_tmp5
    %Sy_var2 = call i64 %Sy_accum_ptr_2(i64 3, ptr %Sy_var1, i64 0)
    call void @syli_rt_object_decr(ptr %Sy_var1)
    call void @syli_rt_object_check_release(ptr %Sy_var1)
    ; nop
    ret i64 %Sy_var2
  }
  
  define i64 @syliTest_file.add__i64__i64__i64_ret_i64(i64 %x, i64 %y, i64 %z) {
  bb0:
    %Sy_var0 = add i64 %x, %y
    %Sy_var1 = add i64 %Sy_var0, %z
    ret i64 %Sy_var1
  }
  
  define i64 @__make_closure_accum.syliTest_file.add.41_ret_i64(i64 %Sy_x0, i64 %Sy_x1, ptr %Sy_clos, i64 %Sy_dp_id) {
  bb0:
    %Sy_tmp0 = getelementptr { i64, i64, [0 x i64] }, ptr %Sy_clos, i32 0, i32 2, i64 1
    %Sy_val0 = load i64, ptr %Sy_tmp0
    %Sy_rst = call i64 @__wrapper.syliTest_file.add.i64_i64_i64_ret_i64(i64 %Sy_val0, i64 %Sy_x0, i64 %Sy_x1)
    ret i64 %Sy_rst
  }
  
  define i64 @__partial_closure_accum.clos1_arg1_ret_i64(i64 %Sy_x0, ptr %Sy_clos, i64 %Sy_dp_id) {
  bb0:
    %Sy_tmp0 = getelementptr { i64, i64, [0 x i64] }, ptr %Sy_clos, i32 0, i32 2, i64 1
    %Sy_p_clos = load ptr, ptr %Sy_tmp0
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr %Sy_p_clos, i32 0, i32 2, i64 0
    %Sy_p_accum = load ptr, ptr %Sy_tmp1
    %Sy_tmp2 = getelementptr { i64, i64, [0 x i64] }, ptr %Sy_clos, i32 0, i32 2, i64 2
    %Sy_val0 = load i64, ptr %Sy_tmp2
    %Sy_rst = call i64 %Sy_p_accum(i64 %Sy_val0, i64 %Sy_x0, ptr %Sy_p_clos, i64 %Sy_dp_id)
    ret i64 %Sy_rst
  }
  
  define i64 @__wrapper.syliTest_file.add.i64_i64_i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1, i64 %Sy_x2) {
  bb0:
    %Sy_rst = call i64 @syliTest_file.add__i64__i64__i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1, i64 %Sy_x2)
    ret i64 %Sy_rst
  }
  
