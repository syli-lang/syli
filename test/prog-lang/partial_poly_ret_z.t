  $ cat >test_multi.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  >   extern syli_print_f64 : double -> unit = "syli_print_f64"
  > end
  > let add x z = z
  > fn main () =
  >   let add1 = add 1
  >   let d = add1 1.0
  >   let i = add1 1
  >   syli_print_i64 i
  >   syli_print_f64 d
  >   i
  > EOF

  $ dune exec sylic -- cir_raw test_multi.sy
  module Test_multi :
  ffi_external_functions:
  extern fn syli_print_i64(i64) -> void
  extern fn syli_print_f64(f64) -> void
  
  
  functions:
  public fn __init.Test_multi() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_multi.main() -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:(?72 -> ?72) = #make_closure {syliTest_multi.add} () ( captured_args=[1:i64])
      %Sy_var1:f64 = #call_apply {%Sy_var0:(?72 -> ?72) as (f64 -> f64)}  (1.0f:f64)
      %Sy_var2:i64 = #call_apply {%Sy_var0:(?72 -> ?72) as (i64 -> i64)}  (1:i64)
      %Sy_var3:void = #call_direct syliTest_multi.syli_print_i64 (%Sy_var2:i64)
      %Sy_var4:void = #call_direct syliTest_multi.syli_print_f64 (%Sy_var1:f64)
      return %Sy_var2:i64
  end
  
  public fn syliTest_multi.add(%x:?65, %z:?67) -> ?67:
    entry: bb0
  
    bb0:
  
      return %z:?67
  end
  
  end

  $ dune exec sylic -- typing test_multi.sy
  Typed test_multi.sy successfully: module Test_multi with 3 top-level typed items
  Type Environment:
  {
    add : forall '65 '67. ('65, '67) -> '67
    main : (unit) -> int64
    syli_print_f64 : (double) -> unit
    syli_print_i64 : (int64) -> unit
  }

  $ dune exec sylic -- oir test_multi.sy
  module Test_multi :
  ffi_external_functions:
  extern fn syli_print_i64(i64) -> void
  extern fn syli_print_f64(f64) -> void
  
  
  functions:
  public fn __init.Test_multi() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_multi.main() -> i64:
    entry: bb0
  
    bb0:
      gc_cycle
      %Sy_var0:*void = object_create{size=2:i32 record{fields=2 tag=0 [fn_ptr; i64]}}
      
      %Sy_accum_fn_0:fn_ptr = addr_fn(__make_closure_accum.dispatch.28_ret_i64)
      obj_set(%Sy_var0:*void, 0:i32, %Sy_accum_fn_0:fn_ptr):fn_ptr
      obj_set(%Sy_var0:*void, 1:i32, 1:i64):i64
      
      %Sy_accum_ptr_1:fn_ptr = obj_get(%Sy_var0:*void, 0:i32):fn_ptr
      %Sy_apply_cast_2:i64 = cast(1.0f:f64 as i64)
      %Sy_apply_tmp_3:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_1:fn_ptr)  (%Sy_apply_cast_2:i64, %Sy_var0:*void, 1:i64)
      %Sy_var1:f64 = cast(%Sy_apply_tmp_3:i64 as f64)
      
      %Sy_accum_ptr_4:fn_ptr = obj_get(%Sy_var0:*void, 0:i32):fn_ptr
      %Sy_var2:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_4:fn_ptr)  (1:i64, %Sy_var0:*void, 0:i64)
      rc_decr(%Sy_var0:*void)
      rc_check_release(%Sy_var0:*void)
      
      %Sy_var3:void = #call_direct syliTest_multi.syli_print_i64 (%Sy_var2:i64)
      %Sy_var4:void = #call_direct syliTest_multi.syli_print_f64 (%Sy_var1:f64)
      return %Sy_var2:i64
  end
  
  public fn syliTest_multi.add__i64__f64_ret_f64(%x:i64, %z:f64) -> f64:
    entry: bb0
  
    bb0:
  
      return %z:f64
  end
  
  public fn syliTest_multi.add__i64__i64_ret_i64(%x:i64, %z:i64) -> i64:
    entry: bb0
  
    bb0:
  
      return %z:i64
  end
  
  private fn __make_closure_accum.dispatch.28_ret_i64(%Sy_x0:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb-1
  
    bb-1:
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 1:i64):i64
      switch %Sy_dp_id:i64 [0: bb0, 1: bb1]
  
    bb0:
      %Sy_case_result0:i64 = #call_direct __wrapper.syliTest_multi.add.i64_i64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64)
      return %Sy_case_result0:i64
  
    bb1:
      %Sy_case_result1:i64 = #call_direct __wrapper.syliTest_multi.add.i64_f64_cast_f64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64)
      return %Sy_case_result1:i64
  end
  
  private fn __wrapper.syliTest_multi.add.i64_f64_cast_f64_ret_i64(%Sy_x0:i64, %Sy_x1:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_s0:i64 = cast(%Sy_x0:i64 as i64)
      %Sy_s1:f64 = cast(%Sy_x1:i64 as f64)
      %Sy_rst:f64 = #call_direct syliTest_multi.add__i64__f64_ret_f64 (%Sy_s0:i64, %Sy_s1:f64)
      %Sy_result:i64 = cast(%Sy_rst:f64 as i64)
      return %Sy_result:i64
  end
  
  private fn __wrapper.syliTest_multi.add.i64_i64_ret_i64(%Sy_x0:i64, %Sy_x1:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_s0:i64 = cast(%Sy_x0:i64 as i64)
      %Sy_s1:i64 = cast(%Sy_x1:i64 as i64)
      %Sy_rst:i64 = #call_direct syliTest_multi.add__i64__i64_ret_i64 (%Sy_s0:i64, %Sy_s1:i64)
      return %Sy_rst:i64
  end
  
  end

