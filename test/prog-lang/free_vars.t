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
  declare void @syli_rt_object_check_release(ptr)
  declare void @syli_rt_object_decr(ptr)
  declare ptr @syli_rt_rc_alloc_object(i64, i32, i32)
  
  define void @__init.Test_multi() {
  bb0:
    ret void
  }
  
  define i64 @syliTest_multi.apply() {
  bb0:
    call void @syli_rt_gc_cycle()
    %syliTest_multi.apply__add = call ptr @syli_rt_rc_alloc_object(i64 3602879701896462337, i32 1, i32 2)
    ; nop
    %Sy_accum_fn_0 = bitcast ptr @__make_closure_accum.syliTest_multi.apply__add.27_ret_i64 to ptr
    %Sy_tmp0 = getelementptr i64, ptr %syliTest_multi.apply__add, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i32 0
    store ptr %Sy_accum_fn_0, ptr %Sy_tmp1
    %Sy_tmp2 = getelementptr i64, ptr %syliTest_multi.apply__add, i32 2
    %Sy_tmp3 = getelementptr i64, ptr %Sy_tmp2, i32 1
    store i64 1, ptr %Sy_tmp3
    ; nop
    %Sy_tmp4 = getelementptr i64, ptr %syliTest_multi.apply__add, i32 2
    %Sy_tmp5 = getelementptr i64, ptr %Sy_tmp4, i32 0
    %Sy_accum_ptr_1 = load ptr, ptr %Sy_tmp5
    %Sy_var0 = call i64 %Sy_accum_ptr_1(i64 1, i64 2, ptr %syliTest_multi.apply__add, i64 0)
    call void @syli_rt_object_decr(ptr %syliTest_multi.apply__add)
    call void @syli_rt_object_check_release(ptr %syliTest_multi.apply__add)
    ; nop
    ret i64 %Sy_var0
  }
  
  define i64 @syliTest_multi.apply__add__i64__i64__i64_ret_i64(i64 %syliTest_multi.apply__free, i64 %x, i64 %y) {
  bb0:
    %Sy_var0 = add i64 %syliTest_multi.apply__free, %y
    ret i64 %Sy_var0
  }
  
  define i64 @__make_closure_accum.syliTest_multi.apply__add.27_ret_i64(i64 %Sy_x0, i64 %Sy_x1, ptr %Sy_clos, i64 %Sy_dp_id) {
  bb0:
    %Sy_tmp0 = getelementptr i64, ptr %Sy_clos, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i64 1
    %Sy_val0 = load i64, ptr %Sy_tmp1
    %Sy_tmp2 = getelementptr i64, ptr %Sy_clos, i32 2
    %Sy_tmp3 = getelementptr i64, ptr %Sy_tmp2, i64 2
    %Sy_val1 = load i64, ptr %Sy_tmp3
    %Sy_rst = call i64 @__wrapper.syliTest_multi.apply__add.i64_i64_i64_ret_i64(i64 %Sy_val0, i64 %Sy_val1, i64 %Sy_x0, i64 %Sy_x1)
    ret i64 %Sy_rst
  }
  
  define i64 @__wrapper.syliTest_multi.apply__add.i64_i64_i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1, i64 %Sy_x2) {
  bb0:
    %Sy_rst = call i64 @syliTest_multi.apply__add__i64__i64__i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1, i64 %Sy_x2)
    ret i64 %Sy_rst
  }
  

