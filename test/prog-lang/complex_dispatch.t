Complex test combining closures, dispatch, casts, partial application, and if-then-else:
  $ cat >complex_dispatch.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > let add x y z = x
  > let apply f x y = f x y
  > fn main () =
  >   let add1 = add 1
  >   let r1 = apply add1 10 20
  >   syli_print_i64 r1
  >   let r2 = apply add1 1.0 2.0
  >   syli_print_i64 r2
  >   let add1and2 = add1 2
  >   let r3 = add1and2 30
  >   syli_print_i64 r3
  >   let r4 = add1and2 3.0
  >   syli_print_i64 r4
  >   let r5 =
  >     if true then
  >       apply add1 100 200
  >     else
  >       apply add1 1.0 2.0
  >   syli_print_i64 r5
  > EOF
  $ dune exec sylic -- core complex_dispatch.sy > complex_dispatch.core
  $ dune exec sylic -- cir complex_dispatch.sy > complex_dispatch.cir
  $ dune exec sylic -- oir complex_dispatch.sy > complex_dispatch.oir
  $ dune exec sylic -- llvm complex_dispatch.sy > complex_dispatch.ll
  $ cat complex_dispatch.core
  module Complex_dispatch
  let syliComplex_dispatch.add = fun (x, y, z) : 'a148 ->
      x : 'a148
  
  let syliComplex_dispatch.apply = fun (f, x, y) : 'a163 ->
      f(x : 'a157, y : 'a159) : 'a163
  
  let syliComplex_dispatch.main = fun () : unit ->
      {
        let syliComplex_dispatch.main__add1 = syliComplex_dispatch.add(1 : i64) : ('a167, 'a168) -> i64
        let syliComplex_dispatch.main__r1 = syliComplex_dispatch.apply(syliComplex_dispatch.main__add1 : (i64, i64) -> i64, 10 : i64, 20 : i64) : i64
        syliComplex_dispatch.syli_print_i64(syliComplex_dispatch.main__r1 : i64) : unit
        let syliComplex_dispatch.main__r2 = syliComplex_dispatch.apply(syliComplex_dispatch.main__add1 : (double, double) -> i64, 1.0 : double, 2.0 : double) : i64
        syliComplex_dispatch.syli_print_i64(syliComplex_dispatch.main__r2 : i64) : unit
        let syliComplex_dispatch.main__add1and2 = syliComplex_dispatch.main__add1(2 : i64) : ('a183) -> i64
        let syliComplex_dispatch.main__r3 = syliComplex_dispatch.main__add1and2(30 : i64) : i64
        syliComplex_dispatch.syli_print_i64(syliComplex_dispatch.main__r3 : i64) : unit
        let syliComplex_dispatch.main__r4 = syliComplex_dispatch.main__add1and2(3.0 : double) : i64
        syliComplex_dispatch.syli_print_i64(syliComplex_dispatch.main__r4 : i64) : unit
        let syliComplex_dispatch.main__r5 = if true : bool
            syliComplex_dispatch.apply(syliComplex_dispatch.main__add1 : (i64, i64) -> i64, 100 : i64, 200 : i64) : i64
          else
            syliComplex_dispatch.apply(syliComplex_dispatch.main__add1 : (double, double) -> i64, 1.0 : double, 2.0 : double) : i64
        syliComplex_dispatch.syli_print_i64(syliComplex_dispatch.main__r5 : i64) : unit
      }
  
  $ cat complex_dispatch.cir
  module Complex_dispatch :
  ffi_external_functions:
  extern fn syli_print_i64(i64) -> void
  
  
  functions:
  public fn __init.Complex_dispatch() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliComplex_dispatch.main() -> void:
    entry: bb0
  
    bb0:
      %Sy_var0:(?167, ?168 -> i64) = #make_closure {syliComplex_dispatch.add} () ( captured_args=[1:i64])
      %Sy_var1:(i64, i64 -> i64) = cast(%Sy_var0:(?167, ?168 -> i64) as (i64, i64 -> i64))
      %Sy_var2:i64 = #call_direct syliComplex_dispatch.apply__fn_i64_i64_i64__i64__i64_ret_i64 (%Sy_var1:(i64, i64 -> i64), 10:i64, 20:i64)
      %Sy_var3:void = #call_direct syliComplex_dispatch.syli_print_i64 (%Sy_var2:i64)
      %Sy_var4:(f64, f64 -> i64) = cast(%Sy_var0:(?167, ?168 -> i64) as (f64, f64 -> i64))
      %Sy_var5:i64 = #call_direct syliComplex_dispatch.apply__fn_f64_f64_i64__f64__f64_ret_i64 (%Sy_var4:(f64, f64 -> i64), 1.0f:f64, 2.0f:f64)
      %Sy_var6:void = #call_direct syliComplex_dispatch.syli_print_i64 (%Sy_var5:i64)
      %Sy_var7:(?183 -> i64) = #partial_apply {%Sy_var0:(?167, ?168 -> i64)} (2:i64)
      %Sy_var8:i64 = #call_apply {%Sy_var7:(?183 -> i64) as (i64 -> i64)}  (30:i64)
      %Sy_var9:void = #call_direct syliComplex_dispatch.syli_print_i64 (%Sy_var8:i64)
      %Sy_var10:i64 = #call_apply {%Sy_var7:(?183 -> i64) as (f64 -> i64)}  (3.0f:f64)
      %Sy_var11:void = #call_direct syliComplex_dispatch.syli_print_i64 (%Sy_var10:i64)
      %Sy_var12:bool = cast(true:bool as bool)
      cond_br %Sy_var12:bool, bb1, bb2
  
    bb2:
      %Sy_var16:(f64, f64 -> i64) = cast(%Sy_var0:(?167, ?168 -> i64) as (f64, f64 -> i64))
      %Sy_var17:i64 = #call_direct syliComplex_dispatch.apply__fn_f64_f64_i64__f64__f64_ret_i64 (%Sy_var16:(f64, f64 -> i64), 1.0f:f64, 2.0f:f64)
      %Sy_var13:i64 = move(%Sy_var17:i64)
      goto bb3
  
    bb1:
      %Sy_var14:(i64, i64 -> i64) = cast(%Sy_var0:(?167, ?168 -> i64) as (i64, i64 -> i64))
      %Sy_var15:i64 = #call_direct syliComplex_dispatch.apply__fn_i64_i64_i64__i64__i64_ret_i64 (%Sy_var14:(i64, i64 -> i64), 100:i64, 200:i64)
      %Sy_var13:i64 = move(%Sy_var15:i64)
      goto bb3
  
    bb3:
      %Sy_var18:void = #call_direct syliComplex_dispatch.syli_print_i64 (%Sy_var13:i64)
      return
  end
  
  public fn syliComplex_dispatch.apply__fn_f64_f64_i64__f64__f64_ret_i64(%f:(f64, f64 -> i64), %x:f64, %y:f64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = #call_apply {%f:(f64, f64 -> i64)}  (%x:f64, %y:f64)
      return %Sy_var0:i64
  end
  
  public fn syliComplex_dispatch.apply__fn_i64_i64_i64__i64__i64_ret_i64(%f:(i64, i64 -> i64), %x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = #call_apply {%f:(i64, i64 -> i64)}  (%x:i64, %y:i64)
      return %Sy_var0:i64
  end
  
  public fn syliComplex_dispatch.add__i64__i64__f64_ret_i64(%x:i64, %y:i64, %z:f64) -> i64:
    entry: bb0
  
    bb0:
  
      return %x:i64
  end
  
  public fn syliComplex_dispatch.add__i64__i64__i64_ret_i64(%x:i64, %y:i64, %z:i64) -> i64:
    entry: bb0
  
    bb0:
  
      return %x:i64
  end
  
  public fn syliComplex_dispatch.add__i64__f64__f64_ret_i64(%x:i64, %y:f64, %z:f64) -> i64:
    entry: bb0
  
    bb0:
  
      return %x:i64
  end
  
  end
  $ cat complex_dispatch.oir
  module Complex_dispatch :
  ffi_external_functions:
  extern fn syli_print_i64(i64) -> void
  
  
  functions:
  public fn __init.Complex_dispatch() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliComplex_dispatch.main() -> void:
    entry: bb0
  
    bb0:
      gc_cycle
      %Sy_var0:*void = object_create{size=2:i32 record{fields=2 tag=0 [fn_ptr; i64]}}
      
      %Sy_accum_fn_0:fn_ptr = addr_fn(__make_closure_accum.dispatch.66_ret_i64)
      obj_set(%Sy_var0:*void, 0:i32, %Sy_accum_fn_0:fn_ptr):fn_ptr
      obj_set(%Sy_var0:*void, 1:i32, 1:i64):i64
      
      gc_cycle
      %Sy_var1:*void = object_create{size=3:i32 record{fields=3 tag=0 [fn_ptr; i64; *void]}}
      
      %Sy_accum_fn_1:fn_ptr = addr_fn(__partial_closure_accum.dispatch.clos0_arg2_ret_i64)
      obj_set(%Sy_var1:*void, 0:i32, %Sy_accum_fn_1:fn_ptr):fn_ptr
      obj_set(%Sy_var1:*void, 1:i32, 5:i64):i64
      obj_set(%Sy_var1:*void, 2:i32, %Sy_var0:*void):*void
      
      %Sy_var2:i64 = #call_direct syliComplex_dispatch.apply__fn_i64_i64_i64__i64__i64_ret_i64 (%Sy_var1:*void, 10:i64, 20:i64)
      rc_decr(%Sy_var1:*void)
      rc_check_release(%Sy_var1:*void)
      %Sy_var3:void = #call_direct syliComplex_dispatch.syli_print_i64 (%Sy_var2:i64)
      gc_cycle
      %Sy_var4:*void = object_create{size=3:i32 record{fields=3 tag=0 [fn_ptr; i64; *void]}}
      
      %Sy_accum_fn_2:fn_ptr = addr_fn(__partial_closure_accum.dispatch.clos0_arg2_ret_i64)
      obj_set(%Sy_var4:*void, 0:i32, %Sy_accum_fn_2:fn_ptr):fn_ptr
      obj_set(%Sy_var4:*void, 1:i32, 4:i64):i64
      obj_set(%Sy_var4:*void, 2:i32, %Sy_var0:*void):*void
      
      %Sy_var5:i64 = #call_direct syliComplex_dispatch.apply__fn_f64_f64_i64__f64__f64_ret_i64 (%Sy_var4:*void, 1.0f:f64, 2.0f:f64)
      rc_decr(%Sy_var4:*void)
      rc_check_release(%Sy_var4:*void)
      %Sy_var6:void = #call_direct syliComplex_dispatch.syli_print_i64 (%Sy_var5:i64)
      gc_cycle
      %Sy_var7:*void = object_create{size=4:i32 record{fields=4 tag=0 [fn_ptr; i64; *void; i64]}}
      
      %Sy_accum_fn_3:fn_ptr = addr_fn(__partial_closure_accum.dispatch.clos1_arg1_ret_i64)
      obj_set(%Sy_var7:*void, 0:i32, %Sy_accum_fn_3:fn_ptr):fn_ptr
      obj_set(%Sy_var7:*void, 1:i32, 2:i64):i64
      obj_set(%Sy_var7:*void, 2:i32, %Sy_var0:*void):*void
      obj_set(%Sy_var7:*void, 3:i32, 2:i64):i64
      
      %Sy_accum_ptr_4:fn_ptr = obj_get(%Sy_var7:*void, 0:i32):fn_ptr
      %Sy_var8:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_4:fn_ptr)  (30:i64, %Sy_var7:*void, 1:i64)
      
      %Sy_var9:void = #call_direct syliComplex_dispatch.syli_print_i64 (%Sy_var8:i64)
      %Sy_accum_ptr_5:fn_ptr = obj_get(%Sy_var7:*void, 0:i32):fn_ptr
      %Sy_apply_cast_6:i64 = cast(3.0f:f64 as i64)
      %Sy_var10:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_5:fn_ptr)  (%Sy_apply_cast_6:i64, %Sy_var7:*void, 0:i64)
      rc_decr(%Sy_var7:*void)
      rc_check_release(%Sy_var7:*void)
      
      %Sy_var11:void = #call_direct syliComplex_dispatch.syli_print_i64 (%Sy_var10:i64)
      %Sy_var12:bool = cast(true:bool as bool)
      cond_br %Sy_var12:bool, bb1, bb2
  
    bb2:
      gc_cycle
      %Sy_var16:*void = object_create{size=3:i32 record{fields=3 tag=0 [fn_ptr; i64; *void]}}
      
      %Sy_accum_fn_7:fn_ptr = addr_fn(__partial_closure_accum.dispatch.clos0_arg2_ret_i64)
      obj_set(%Sy_var16:*void, 0:i32, %Sy_accum_fn_7:fn_ptr):fn_ptr
      obj_set(%Sy_var16:*void, 1:i32, 1:i64):i64
      obj_set(%Sy_var16:*void, 2:i32, %Sy_var0:*void):*void
      rc_decr(%Sy_var0:*void)
      rc_check_release(%Sy_var0:*void)
      
      %Sy_var17:i64 = #call_direct syliComplex_dispatch.apply__fn_f64_f64_i64__f64__f64_ret_i64 (%Sy_var16:*void, 1.0f:f64, 2.0f:f64)
      rc_decr(%Sy_var16:*void)
      rc_check_release(%Sy_var16:*void)
      %Sy_var13:i64 = move(%Sy_var17:i64)
      goto bb3
  
    bb1:
      gc_cycle
      %Sy_var14:*void = object_create{size=2:i32 record{fields=2 tag=0 [fn_ptr; *void]}}
      
      %Sy_accum_fn_8:fn_ptr = addr_fn(__partial_closure_accum.clos0_arg2_ret_i64)
      obj_set(%Sy_var14:*void, 0:i32, %Sy_accum_fn_8:fn_ptr):fn_ptr
      obj_set(%Sy_var14:*void, 1:i32, %Sy_var0:*void):*void
      rc_decr(%Sy_var0:*void)
      rc_check_release(%Sy_var0:*void)
      
      %Sy_var15:i64 = #call_direct syliComplex_dispatch.apply__fn_i64_i64_i64__i64__i64_ret_i64 (%Sy_var14:*void, 100:i64, 200:i64)
      rc_decr(%Sy_var14:*void)
      rc_check_release(%Sy_var14:*void)
      %Sy_var13:i64 = move(%Sy_var15:i64)
      goto bb3
  
    bb3:
      %Sy_var18:void = #call_direct syliComplex_dispatch.syli_print_i64 (%Sy_var13:i64)
      return
  end
  
  public fn syliComplex_dispatch.apply__fn_f64_f64_i64__f64__f64_ret_i64(%f:*void, %x:f64, %y:f64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_accum_ptr_9:fn_ptr = obj_get(%f:*void, 0:i32):fn_ptr
      %Sy_apply_cast_10:i64 = cast(%x:f64 as i64)
      %Sy_apply_cast_11:i64 = cast(%y:f64 as i64)
      %Sy_var0:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_9:fn_ptr)  (%Sy_apply_cast_10:i64, %Sy_apply_cast_11:i64, %f:*void, 0:i64)
      
      return %Sy_var0:i64
  end
  
  public fn syliComplex_dispatch.apply__fn_i64_i64_i64__i64__i64_ret_i64(%f:*void, %x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_accum_ptr_12:fn_ptr = obj_get(%f:*void, 0:i32):fn_ptr
      %Sy_var0:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_12:fn_ptr)  (%x:i64, %y:i64, %f:*void, 0:i64)
      
      return %Sy_var0:i64
  end
  
  public fn syliComplex_dispatch.add__i64__i64__f64_ret_i64(%x:i64, %y:i64, %z:f64) -> i64:
    entry: bb0
  
    bb0:
  
      return %x:i64
  end
  
  public fn syliComplex_dispatch.add__i64__i64__i64_ret_i64(%x:i64, %y:i64, %z:i64) -> i64:
    entry: bb0
  
    bb0:
  
      return %x:i64
  end
  
  public fn syliComplex_dispatch.add__i64__f64__f64_ret_i64(%x:i64, %y:f64, %z:f64) -> i64:
    entry: bb0
  
    bb0:
  
      return %x:i64
  end
  
  private fn __make_closure_accum.dispatch.66_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb-1
  
    bb-1:
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 1:i64):i64
      switch %Sy_dp_id:i64 [1: bb1, 0: bb0, 2: bb2, 3: bb3, 4: bb4, 5: bb5]
  
    bb1:
      %Sy_case_result1:i64 = #call_direct __wrapper.syliComplex_dispatch.add.i64_f64_f64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64, %Sy_x1:i64)
      return %Sy_case_result1:i64
  
    bb0:
      %Sy_case_result0:i64 = #call_direct __wrapper.syliComplex_dispatch.add.i64_i64_i64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64, %Sy_x1:i64)
      return %Sy_case_result0:i64
  
    bb2:
      %Sy_case_result2:i64 = #call_direct __wrapper.syliComplex_dispatch.add.i64_i64_f64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64, %Sy_x1:i64)
      return %Sy_case_result2:i64
  
    bb3:
      %Sy_case_result3:i64 = #call_direct __wrapper.syliComplex_dispatch.add.i64_i64_i64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64, %Sy_x1:i64)
      return %Sy_case_result3:i64
  
    bb4:
      %Sy_case_result4:i64 = #call_direct __wrapper.syliComplex_dispatch.add.i64_f64_f64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64, %Sy_x1:i64)
      return %Sy_case_result4:i64
  
    bb5:
      %Sy_case_result5:i64 = #call_direct __wrapper.syliComplex_dispatch.add.i64_i64_i64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64, %Sy_x1:i64)
      return %Sy_case_result5:i64
  end
  
  private fn __partial_closure_accum.clos0_arg2_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_p_clos:*void = obj_get(%Sy_clos:*void, 1:i64):*void
      %Sy_p_accum:fn_ptr = obj_get(%Sy_p_clos:*void, 0:i64):fn_ptr
      %Sy_rst:i64 = #call_direct_fn_ptr(%Sy_p_accum:fn_ptr)  (%Sy_x0:i64, %Sy_x1:i64, %Sy_p_clos:*void, %Sy_dp_id:i64)
      return %Sy_rst:i64
  end
  
  private fn __partial_closure_accum.dispatch.clos0_arg2_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_dp_clos:i64 = obj_get(%Sy_clos:*void, 1:i64):i64
      %Sy_accum_dp_id:i64 = %Sy_dp_id:i64 + %Sy_dp_clos:i64
      %Sy_p_clos:*void = obj_get(%Sy_clos:*void, 2:i64):*void
      %Sy_p_accum:fn_ptr = obj_get(%Sy_p_clos:*void, 0:i64):fn_ptr
      %Sy_rst:i64 = #call_direct_fn_ptr(%Sy_p_accum:fn_ptr)  (%Sy_x0:i64, %Sy_x1:i64, %Sy_p_clos:*void, %Sy_accum_dp_id:i64)
      return %Sy_rst:i64
  end
  
  private fn __partial_closure_accum.dispatch.clos1_arg1_ret_i64(%Sy_x0:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_dp_clos:i64 = obj_get(%Sy_clos:*void, 1:i64):i64
      %Sy_accum_dp_id:i64 = %Sy_dp_id:i64 + %Sy_dp_clos:i64
      %Sy_p_clos:*void = obj_get(%Sy_clos:*void, 2:i64):*void
      %Sy_p_accum:fn_ptr = obj_get(%Sy_p_clos:*void, 0:i64):fn_ptr
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 3:i64):i64
      %Sy_rst:i64 = #call_direct_fn_ptr(%Sy_p_accum:fn_ptr)  (%Sy_val0:i64, %Sy_x0:i64, %Sy_p_clos:*void, %Sy_accum_dp_id:i64)
      return %Sy_rst:i64
  end
  
  private fn __wrapper.syliComplex_dispatch.add.i64_f64_f64_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_x2:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_s0:i64 = cast(%Sy_x0:i64 as i64)
      %Sy_s1:f64 = cast(%Sy_x1:i64 as f64)
      %Sy_s2:f64 = cast(%Sy_x2:i64 as f64)
      %Sy_rst:i64 = #call_direct syliComplex_dispatch.add__i64__f64__f64_ret_i64 (%Sy_s0:i64, %Sy_s1:f64, %Sy_s2:f64)
      return %Sy_rst:i64
  end
  
  private fn __wrapper.syliComplex_dispatch.add.i64_i64_f64_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_x2:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_s0:i64 = cast(%Sy_x0:i64 as i64)
      %Sy_s1:i64 = cast(%Sy_x1:i64 as i64)
      %Sy_s2:f64 = cast(%Sy_x2:i64 as f64)
      %Sy_rst:i64 = #call_direct syliComplex_dispatch.add__i64__i64__f64_ret_i64 (%Sy_s0:i64, %Sy_s1:i64, %Sy_s2:f64)
      return %Sy_rst:i64
  end
  
  private fn __wrapper.syliComplex_dispatch.add.i64_i64_i64_ret_i64(%Sy_x0:i64, %Sy_x1:i64, %Sy_x2:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_s0:i64 = cast(%Sy_x0:i64 as i64)
      %Sy_s1:i64 = cast(%Sy_x1:i64 as i64)
      %Sy_s2:i64 = cast(%Sy_x2:i64 as i64)
      %Sy_rst:i64 = #call_direct syliComplex_dispatch.add__i64__i64__i64_ret_i64 (%Sy_s0:i64, %Sy_s1:i64, %Sy_s2:i64)
      return %Sy_rst:i64
  end
  
  end

