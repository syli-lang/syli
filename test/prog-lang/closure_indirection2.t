  $ cat >test_file.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > let add x y = x + y
  > let sub x y = x - y
  > let mul x y = x * y
  > fn main () =
  >   let add1 = add 1
  >   let sub1 = sub 1
  >   let mul1 = mul 1
  >   let f = if true then add1 else if true then sub1 else mul1
  >   let result = f 2
  >   syli_print_i64 result
  > EOF
  $ dune exec sylic -- core test_file.sy > test_file.core
  $ dune exec sylic -- cir test_file.sy > test_file.ir
  $ dune exec sylic -- oir test_file.sy > test_file.oir
  $ dune exec sylic -- llvm test_file.sy > test_file.ll
  $ cat test_file.core
  module Test_file
  let syliTest_file.add = fun (x, y) : 'a107 ->
      (x : 'a107 + y : 'a107) : 'a107
  
  let syliTest_file.sub = fun (x, y) : 'a112 ->
      (x : 'a112 - y : 'a112) : 'a112
  
  let syliTest_file.mul = fun (x, y) : 'a117 ->
      (x : 'a117 * y : 'a117) : 'a117
  
  let syliTest_file.main = fun () : unit ->
      {
        let syliTest_file.main__add1 = syliTest_file.add(1 : i64) : (i64) -> i64
        let syliTest_file.main__sub1 = syliTest_file.sub(1 : i64) : (i64) -> i64
        let syliTest_file.main__mul1 = syliTest_file.mul(1 : i64) : (i64) -> i64
        let syliTest_file.main__f = if true : bool
            syliTest_file.main__add1 : (i64) -> i64
          else
            if true : bool
              syliTest_file.main__sub1 : (i64) -> i64
            else
              syliTest_file.main__mul1 : (i64) -> i64
        let syliTest_file.main__result = syliTest_file.main__f(2 : i64) : i64
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
      %Sy_var0:(i64 -> i64) = #make_closure {syliTest_file.add} () ( captured_args=[1:i64])
      %Sy_var1:(i64 -> i64) = #make_closure {syliTest_file.sub} () ( captured_args=[1:i64])
      %Sy_var2:(i64 -> i64) = #make_closure {syliTest_file.mul} () ( captured_args=[1:i64])
      %Sy_var3:bool = cast(true:bool as bool)
      cond_br %Sy_var3:bool, bb1, bb2
  
    bb2:
      %Sy_var5:bool = cast(true:bool as bool)
      cond_br %Sy_var5:bool, bb3, bb4
  
    bb4:
      %Sy_var6:(i64 -> i64) = move(%Sy_var2:(i64 -> i64))
      goto bb5
  
    bb3:
      %Sy_var6:(i64 -> i64) = move(%Sy_var1:(i64 -> i64))
      goto bb5
  
    bb5:
      %Sy_var4:(i64 -> i64) = move(%Sy_var6:(i64 -> i64))
      goto bb6
  
    bb1:
      %Sy_var4:(i64 -> i64) = move(%Sy_var0:(i64 -> i64))
      goto bb6
  
    bb6:
      %Sy_var7:i64 = #call_apply {%Sy_var4:(i64 -> i64)}  (2:i64)
      %Sy_var8:void = #call_direct syliTest_file.syli_print_i64 (%Sy_var7:i64)
      return
  end
  
  public fn syliTest_file.mul__i64__i64_ret_i64(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 * %y:i64
      return %Sy_var0:i64
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
      gc_cycle
      %Sy_var0:*void = object_create{size=2:i32 record{fields=2 tag=0 [fn_ptr; i64]}}
      
      %Sy_accum_fn_0:fn_ptr = addr_fn(__make_closure_accum.syliTest_file.add.68_ret_i64)
      obj_set(%Sy_var0:*void, 0:i32, %Sy_accum_fn_0:fn_ptr):fn_ptr
      obj_set(%Sy_var0:*void, 1:i32, 1:i64):i64
      
      gc_cycle
      %Sy_var1:*void = object_create{size=2:i32 record{fields=2 tag=0 [fn_ptr; i64]}}
      
      %Sy_accum_fn_1:fn_ptr = addr_fn(__make_closure_accum.syliTest_file.sub.78_ret_i64)
      obj_set(%Sy_var1:*void, 0:i32, %Sy_accum_fn_1:fn_ptr):fn_ptr
      obj_set(%Sy_var1:*void, 1:i32, 1:i64):i64
      
      gc_cycle
      %Sy_var2:*void = object_create{size=2:i32 record{fields=2 tag=0 [fn_ptr; i64]}}
      
      %Sy_accum_fn_2:fn_ptr = addr_fn(__make_closure_accum.syliTest_file.mul.88_ret_i64)
      obj_set(%Sy_var2:*void, 0:i32, %Sy_accum_fn_2:fn_ptr):fn_ptr
      obj_set(%Sy_var2:*void, 1:i32, 1:i64):i64
      
      %Sy_var3:bool = cast(true:bool as bool)
      cond_br %Sy_var3:bool, bb1, bb2
  
    bb2:
      %Sy_var5:bool = cast(true:bool as bool)
      cond_br %Sy_var5:bool, bb3, bb4
  
    bb4:
      %Sy_var6:*void = move(%Sy_var2:*void)
      rc_decr(%Sy_var2:*void)
      rc_check_release(%Sy_var2:*void)
      goto bb5
  
    bb3:
      %Sy_var6:*void = move(%Sy_var1:*void)
      rc_decr(%Sy_var1:*void)
      rc_check_release(%Sy_var1:*void)
      goto bb5
  
    bb5:
      %Sy_var4:*void = move(%Sy_var6:*void)
      rc_decr(%Sy_var6:*void)
      rc_check_release(%Sy_var6:*void)
      goto bb6
  
    bb1:
      %Sy_var4:*void = move(%Sy_var0:*void)
      rc_decr(%Sy_var0:*void)
      rc_check_release(%Sy_var0:*void)
      goto bb6
  
    bb6:
      %Sy_accum_ptr_3:fn_ptr = obj_get(%Sy_var4:*void, 0:i32):fn_ptr
      %Sy_var7:i64 = #call_direct_fn_ptr(%Sy_accum_ptr_3:fn_ptr)  (2:i64, %Sy_var4:*void, 0:i64)
      rc_decr(%Sy_var4:*void)
      rc_check_release(%Sy_var4:*void)
      
      %Sy_var8:void = #call_direct syliTest_file.syli_print_i64 (%Sy_var7:i64)
      return
  end
  
  public fn syliTest_file.mul__i64__i64_ret_i64(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %x:i64 * %y:i64
      return %Sy_var0:i64
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
  
  private fn __make_closure_accum.syliTest_file.add.68_ret_i64(%Sy_x0:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 1:i64):i64
      %Sy_rst:i64 = #call_direct __wrapper.syliTest_file.add.i64_i64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64)
      return %Sy_rst:i64
  end
  
  private fn __make_closure_accum.syliTest_file.mul.88_ret_i64(%Sy_x0:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 1:i64):i64
      %Sy_rst:i64 = #call_direct __wrapper.syliTest_file.mul.i64_i64_ret_i64 (%Sy_val0:i64, %Sy_x0:i64)
      return %Sy_rst:i64
  end
  
  private fn __make_closure_accum.syliTest_file.sub.78_ret_i64(%Sy_x0:i64, %Sy_clos:*void, %Sy_dp_id:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_val0:i64 = obj_get(%Sy_clos:*void, 1:i64):i64
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
  
  private fn __wrapper.syliTest_file.mul.i64_i64_ret_i64(%Sy_x0:i64, %Sy_x1:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_s0:i64 = cast(%Sy_x0:i64 as i64)
      %Sy_s1:i64 = cast(%Sy_x1:i64 as i64)
      %Sy_rst:i64 = #call_direct syliTest_file.mul__i64__i64_ret_i64 (%Sy_s0:i64, %Sy_s1:i64)
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
    %Sy_var6 = alloca ptr
    %Sy_var4 = alloca ptr
    call void @syli_rt_gc_cycle()
    %Sy_var0 = call ptr @syli_rt_rc_alloc_object(i64 3602879701896462337, i32 1, i32 2)
    ; nop
    %Sy_accum_fn_0 = bitcast ptr @__make_closure_accum.syliTest_file.add.68_ret_i64 to ptr
    %Sy_tmp0 = getelementptr i64, ptr %Sy_var0, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i32 0
    store ptr %Sy_accum_fn_0, ptr %Sy_tmp1
    %Sy_tmp2 = getelementptr i64, ptr %Sy_var0, i32 2
    %Sy_tmp3 = getelementptr i64, ptr %Sy_tmp2, i32 1
    store i64 1, ptr %Sy_tmp3
    ; nop
    call void @syli_rt_gc_cycle()
    %Sy_var1 = call ptr @syli_rt_rc_alloc_object(i64 3602879701896462337, i32 1, i32 2)
    ; nop
    %Sy_accum_fn_1 = bitcast ptr @__make_closure_accum.syliTest_file.sub.78_ret_i64 to ptr
    %Sy_tmp4 = getelementptr i64, ptr %Sy_var1, i32 2
    %Sy_tmp5 = getelementptr i64, ptr %Sy_tmp4, i32 0
    store ptr %Sy_accum_fn_1, ptr %Sy_tmp5
    %Sy_tmp6 = getelementptr i64, ptr %Sy_var1, i32 2
    %Sy_tmp7 = getelementptr i64, ptr %Sy_tmp6, i32 1
    store i64 1, ptr %Sy_tmp7
    ; nop
    call void @syli_rt_gc_cycle()
    %Sy_var2 = call ptr @syli_rt_rc_alloc_object(i64 3602879701896462337, i32 1, i32 2)
    ; nop
    %Sy_accum_fn_2 = bitcast ptr @__make_closure_accum.syliTest_file.mul.88_ret_i64 to ptr
    %Sy_tmp8 = getelementptr i64, ptr %Sy_var2, i32 2
    %Sy_tmp9 = getelementptr i64, ptr %Sy_tmp8, i32 0
    store ptr %Sy_accum_fn_2, ptr %Sy_tmp9
    %Sy_tmp10 = getelementptr i64, ptr %Sy_var2, i32 2
    %Sy_tmp11 = getelementptr i64, ptr %Sy_tmp10, i32 1
    store i64 1, ptr %Sy_tmp11
    ; nop
    br i1 true, label %bb1, label %bb2
  bb2:
    br i1 true, label %bb3, label %bb4
  bb4:
    store ptr %Sy_var2, ptr %Sy_var6
    call void @syli_rt_object_decr(ptr %Sy_var2)
    call void @syli_rt_object_check_release(ptr %Sy_var2)
    br label %bb5
  bb3:
    store ptr %Sy_var1, ptr %Sy_var6
    call void @syli_rt_object_decr(ptr %Sy_var1)
    call void @syli_rt_object_check_release(ptr %Sy_var1)
    br label %bb5
  bb5:
    %Sy_tmp12 = load ptr, ptr %Sy_var6
    store ptr %Sy_tmp12, ptr %Sy_var4
    %Sy_tmp13 = load ptr, ptr %Sy_var6
    call void @syli_rt_object_decr(ptr %Sy_tmp13)
    %Sy_tmp14 = load ptr, ptr %Sy_var6
    call void @syli_rt_object_check_release(ptr %Sy_tmp14)
    br label %bb6
  bb1:
    store ptr %Sy_var0, ptr %Sy_var4
    call void @syli_rt_object_decr(ptr %Sy_var0)
    call void @syli_rt_object_check_release(ptr %Sy_var0)
    br label %bb6
  bb6:
    %Sy_tmp15 = load ptr, ptr %Sy_var4
    %Sy_tmp16 = getelementptr i64, ptr %Sy_tmp15, i32 2
    %Sy_tmp17 = getelementptr i64, ptr %Sy_tmp16, i32 0
    %Sy_accum_ptr_3 = load ptr, ptr %Sy_tmp17
    %Sy_tmp18 = load ptr, ptr %Sy_var4
    %Sy_var7 = call i64 %Sy_accum_ptr_3(i64 2, ptr %Sy_tmp18, i64 0)
    %Sy_tmp19 = load ptr, ptr %Sy_var4
    call void @syli_rt_object_decr(ptr %Sy_tmp19)
    %Sy_tmp20 = load ptr, ptr %Sy_var4
    call void @syli_rt_object_check_release(ptr %Sy_tmp20)
    ; nop
    call void @syli_print_i64(i64 %Sy_var7)
    ret void
  }
  
  define i64 @syliTest_file.mul__i64__i64_ret_i64(i64 %x, i64 %y) {
  bb0:
    %Sy_var0 = mul i64 %x, %y
    ret i64 %Sy_var0
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
  
  define i64 @__make_closure_accum.syliTest_file.add.68_ret_i64(i64 %Sy_x0, ptr %Sy_clos, i64 %Sy_dp_id) {
  bb0:
    %Sy_tmp0 = getelementptr i64, ptr %Sy_clos, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i64 1
    %Sy_val0 = load i64, ptr %Sy_tmp1
    %Sy_rst = call i64 @__wrapper.syliTest_file.add.i64_i64_ret_i64(i64 %Sy_val0, i64 %Sy_x0)
    ret i64 %Sy_rst
  }
  
  define i64 @__make_closure_accum.syliTest_file.mul.88_ret_i64(i64 %Sy_x0, ptr %Sy_clos, i64 %Sy_dp_id) {
  bb0:
    %Sy_tmp0 = getelementptr i64, ptr %Sy_clos, i32 2
    %Sy_tmp1 = getelementptr i64, ptr %Sy_tmp0, i64 1
    %Sy_val0 = load i64, ptr %Sy_tmp1
    %Sy_rst = call i64 @__wrapper.syliTest_file.mul.i64_i64_ret_i64(i64 %Sy_val0, i64 %Sy_x0)
    ret i64 %Sy_rst
  }
  
  define i64 @__make_closure_accum.syliTest_file.sub.78_ret_i64(i64 %Sy_x0, ptr %Sy_clos, i64 %Sy_dp_id) {
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
  
  define i64 @__wrapper.syliTest_file.mul.i64_i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1) {
  bb0:
    %Sy_rst = call i64 @syliTest_file.mul__i64__i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1)
    ret i64 %Sy_rst
  }
  
  define i64 @__wrapper.syliTest_file.sub.i64_i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1) {
  bb0:
    %Sy_rst = call i64 @syliTest_file.sub__i64__i64_ret_i64(i64 %Sy_x0, i64 %Sy_x1)
    ret i64 %Sy_rst
  }
  


  $ opt -passes=mem2reg test_file.ll -S -o test_file_opt.ll
  $ opt --O3 -S test_file.ll -o test_file_O3.ll
  $ llc test_file_O3.ll
  $ cat test_file_O3.s
  	.text
  	.file	"test_file.ll"
  	.globl	syli_startup_program            # -- Begin function syli_startup_program
  	.p2align	4, 0x90
  	.type	syli_startup_program,@function
  syli_startup_program:                   # @syli_startup_program
  	.cfi_startproc
  # %bb.0:                                # %bb0
  	pushq	%rax
  	.cfi_def_cfa_offset 16
  	callq	syliTest_file.main@PLT
  	xorl	%eax, %eax
  	popq	%rcx
  	.cfi_def_cfa_offset 8
  	retq
  .Lfunc_end0:
  	.size	syli_startup_program, .Lfunc_end0-syli_startup_program
  	.cfi_endproc
                                          # -- End function
  	.globl	syli_modules_init               # -- Begin function syli_modules_init
  	.p2align	4, 0x90
  	.type	syli_modules_init,@function
  syli_modules_init:                      # @syli_modules_init
  # %bb.0:                                # %bb0
  	retq
  .Lfunc_end1:
  	.size	syli_modules_init, .Lfunc_end1-syli_modules_init
                                          # -- End function
  	.globl	__init.Test_file                # -- Begin function __init.Test_file
  	.p2align	4, 0x90
  	.type	__init.Test_file,@function
  __init.Test_file:                       # @__init.Test_file
  # %bb.0:                                # %bb0
  	retq
  .Lfunc_end2:
  	.size	__init.Test_file, .Lfunc_end2-__init.Test_file
                                          # -- End function
  	.globl	syliTest_file.main              # -- Begin function syliTest_file.main
  	.p2align	4, 0x90
  	.type	syliTest_file.main,@function
  syliTest_file.main:                     # @syliTest_file.main
  	.cfi_startproc
  # %bb.0:                                # %bb0
  	pushq	%r14
  	.cfi_def_cfa_offset 16
  	pushq	%rbx
  	.cfi_def_cfa_offset 24
  	pushq	%rax
  	.cfi_def_cfa_offset 32
  	.cfi_offset %rbx, -24
  	.cfi_offset %r14, -16
  	callq	syli_rt_gc_cycle@PLT
  	movabsq	$3602879701896462337, %r14      # imm = 0x3200000000010001
  	movq	%r14, %rdi
  	movl	$1, %esi
  	movl	$2, %edx
  	callq	syli_rt_rc_alloc_object@PLT
  	movq	%rax, %rbx
  	movq	__make_closure_accum.syliTest_file.add.68_ret_i64@GOTPCREL(%rip), %rax
  	movq	%rax, 16(%rbx)
  	movq	$1, 24(%rbx)
  	callq	syli_rt_gc_cycle@PLT
  	movq	%r14, %rdi
  	movl	$1, %esi
  	movl	$2, %edx
  	callq	syli_rt_rc_alloc_object@PLT
  	movq	__make_closure_accum.syliTest_file.sub.78_ret_i64@GOTPCREL(%rip), %rcx
  	movq	%rcx, 16(%rax)
  	movq	$1, 24(%rax)
  	callq	syli_rt_gc_cycle@PLT
  	movq	%r14, %rdi
  	movl	$1, %esi
  	movl	$2, %edx
  	callq	syli_rt_rc_alloc_object@PLT
  	movq	__make_closure_accum.syliTest_file.mul.88_ret_i64@GOTPCREL(%rip), %rcx
  	movq	%rcx, 16(%rax)
  	movq	$1, 24(%rax)
  	movq	%rbx, %rdi
  	callq	syli_rt_object_decr@PLT
  	movq	%rbx, %rdi
  	callq	syli_rt_object_check_release@PLT
  	movl	$2, %edi
  	movq	%rbx, %rsi
  	xorl	%edx, %edx
  	callq	*16(%rbx)
  	movq	%rax, %r14
  	movq	%rbx, %rdi
  	callq	syli_rt_object_decr@PLT
  	movq	%rbx, %rdi
  	callq	syli_rt_object_check_release@PLT
  	movq	%r14, %rdi
  	addq	$8, %rsp
  	.cfi_def_cfa_offset 24
  	popq	%rbx
  	.cfi_def_cfa_offset 16
  	popq	%r14
  	.cfi_def_cfa_offset 8
  	jmp	syli_print_i64@PLT              # TAILCALL
  .Lfunc_end3:
  	.size	syliTest_file.main, .Lfunc_end3-syliTest_file.main
  	.cfi_endproc
                                          # -- End function
  	.globl	syliTest_file.mul__i64__i64_ret_i64 # -- Begin function syliTest_file.mul__i64__i64_ret_i64
  	.p2align	4, 0x90
  	.type	syliTest_file.mul__i64__i64_ret_i64,@function
  syliTest_file.mul__i64__i64_ret_i64:    # @syliTest_file.mul__i64__i64_ret_i64
  # %bb.0:                                # %bb0
  	movq	%rdi, %rax
  	imulq	%rsi, %rax
  	retq
  .Lfunc_end4:
  	.size	syliTest_file.mul__i64__i64_ret_i64, .Lfunc_end4-syliTest_file.mul__i64__i64_ret_i64
                                          # -- End function
  	.globl	syliTest_file.sub__i64__i64_ret_i64 # -- Begin function syliTest_file.sub__i64__i64_ret_i64
  	.p2align	4, 0x90
  	.type	syliTest_file.sub__i64__i64_ret_i64,@function
  syliTest_file.sub__i64__i64_ret_i64:    # @syliTest_file.sub__i64__i64_ret_i64
  # %bb.0:                                # %bb0
  	movq	%rdi, %rax
  	subq	%rsi, %rax
  	retq
  .Lfunc_end5:
  	.size	syliTest_file.sub__i64__i64_ret_i64, .Lfunc_end5-syliTest_file.sub__i64__i64_ret_i64
                                          # -- End function
  	.globl	syliTest_file.add__i64__i64_ret_i64 # -- Begin function syliTest_file.add__i64__i64_ret_i64
  	.p2align	4, 0x90
  	.type	syliTest_file.add__i64__i64_ret_i64,@function
  syliTest_file.add__i64__i64_ret_i64:    # @syliTest_file.add__i64__i64_ret_i64
  # %bb.0:                                # %bb0
  	leaq	(%rdi,%rsi), %rax
  	retq
  .Lfunc_end6:
  	.size	syliTest_file.add__i64__i64_ret_i64, .Lfunc_end6-syliTest_file.add__i64__i64_ret_i64
                                          # -- End function
  	.globl	__make_closure_accum.syliTest_file.add.68_ret_i64 # -- Begin function __make_closure_accum.syliTest_file.add.68_ret_i64
  	.p2align	4, 0x90
  	.type	__make_closure_accum.syliTest_file.add.68_ret_i64,@function
  __make_closure_accum.syliTest_file.add.68_ret_i64: # @__make_closure_accum.syliTest_file.add.68_ret_i64
  # %bb.0:                                # %bb0
  	movq	%rdi, %rax
  	addq	24(%rsi), %rax
  	retq
  .Lfunc_end7:
  	.size	__make_closure_accum.syliTest_file.add.68_ret_i64, .Lfunc_end7-__make_closure_accum.syliTest_file.add.68_ret_i64
                                          # -- End function
  	.globl	__make_closure_accum.syliTest_file.mul.88_ret_i64 # -- Begin function __make_closure_accum.syliTest_file.mul.88_ret_i64
  	.p2align	4, 0x90
  	.type	__make_closure_accum.syliTest_file.mul.88_ret_i64,@function
  __make_closure_accum.syliTest_file.mul.88_ret_i64: # @__make_closure_accum.syliTest_file.mul.88_ret_i64
  # %bb.0:                                # %bb0
  	movq	%rdi, %rax
  	imulq	24(%rsi), %rax
  	retq
  .Lfunc_end8:
  	.size	__make_closure_accum.syliTest_file.mul.88_ret_i64, .Lfunc_end8-__make_closure_accum.syliTest_file.mul.88_ret_i64
                                          # -- End function
  	.globl	__make_closure_accum.syliTest_file.sub.78_ret_i64 # -- Begin function __make_closure_accum.syliTest_file.sub.78_ret_i64
  	.p2align	4, 0x90
  	.type	__make_closure_accum.syliTest_file.sub.78_ret_i64,@function
  __make_closure_accum.syliTest_file.sub.78_ret_i64: # @__make_closure_accum.syliTest_file.sub.78_ret_i64
  # %bb.0:                                # %bb0
  	movq	24(%rsi), %rax
  	subq	%rdi, %rax
  	retq
  .Lfunc_end9:
  	.size	__make_closure_accum.syliTest_file.sub.78_ret_i64, .Lfunc_end9-__make_closure_accum.syliTest_file.sub.78_ret_i64
                                          # -- End function
  	.globl	__wrapper.syliTest_file.add.i64_i64_ret_i64 # -- Begin function __wrapper.syliTest_file.add.i64_i64_ret_i64
  	.p2align	4, 0x90
  	.type	__wrapper.syliTest_file.add.i64_i64_ret_i64,@function
  __wrapper.syliTest_file.add.i64_i64_ret_i64: # @__wrapper.syliTest_file.add.i64_i64_ret_i64
  # %bb.0:                                # %bb0
  	leaq	(%rdi,%rsi), %rax
  	retq
  .Lfunc_end10:
  	.size	__wrapper.syliTest_file.add.i64_i64_ret_i64, .Lfunc_end10-__wrapper.syliTest_file.add.i64_i64_ret_i64
                                          # -- End function
  	.globl	__wrapper.syliTest_file.mul.i64_i64_ret_i64 # -- Begin function __wrapper.syliTest_file.mul.i64_i64_ret_i64
  	.p2align	4, 0x90
  	.type	__wrapper.syliTest_file.mul.i64_i64_ret_i64,@function
  __wrapper.syliTest_file.mul.i64_i64_ret_i64: # @__wrapper.syliTest_file.mul.i64_i64_ret_i64
  # %bb.0:                                # %bb0
  	movq	%rdi, %rax
  	imulq	%rsi, %rax
  	retq
  .Lfunc_end11:
  	.size	__wrapper.syliTest_file.mul.i64_i64_ret_i64, .Lfunc_end11-__wrapper.syliTest_file.mul.i64_i64_ret_i64
                                          # -- End function
  	.globl	__wrapper.syliTest_file.sub.i64_i64_ret_i64 # -- Begin function __wrapper.syliTest_file.sub.i64_i64_ret_i64
  	.p2align	4, 0x90
  	.type	__wrapper.syliTest_file.sub.i64_i64_ret_i64,@function
  __wrapper.syliTest_file.sub.i64_i64_ret_i64: # @__wrapper.syliTest_file.sub.i64_i64_ret_i64
  # %bb.0:                                # %bb0
  	movq	%rdi, %rax
  	subq	%rsi, %rax
  	retq
  .Lfunc_end12:
  	.size	__wrapper.syliTest_file.sub.i64_i64_ret_i64, .Lfunc_end12-__wrapper.syliTest_file.sub.i64_i64_ret_i64
                                          # -- End function
  	.section	".note.GNU-stack","",@progbits
