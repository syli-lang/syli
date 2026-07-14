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
    %Sy_var0 = call ptr @syli_rt_rc_alloc_object(i64 3026418949592973313, i32 1, i32 1)
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
  
  $ llc test_file.ll
  $ cat test_file.s
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
  	callq	syli_modules_init@PLT
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
  	.cfi_startproc
  # %bb.0:                                # %bb0
  	pushq	%rax
  	.cfi_def_cfa_offset 16
  	callq	__init.Test_file@PLT
  	popq	%rax
  	.cfi_def_cfa_offset 8
  	retq
  .Lfunc_end1:
  	.size	syli_modules_init, .Lfunc_end1-syli_modules_init
  	.cfi_endproc
                                          # -- End function
  	.globl	__init.Test_file                # -- Begin function __init.Test_file
  	.p2align	4, 0x90
  	.type	__init.Test_file,@function
  __init.Test_file:                       # @__init.Test_file
  	.cfi_startproc
  # %bb.0:                                # %bb0
  	retq
  .Lfunc_end2:
  	.size	__init.Test_file, .Lfunc_end2-__init.Test_file
  	.cfi_endproc
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
  	movabsq	$3026418949592973313, %rdi      # imm = 0x2A00000000000001
  	movl	$1, %esi
  	movl	$1, %edx
  	callq	syli_rt_rc_alloc_object@PLT
  	movq	%rax, %rbx
  	movq	__make_closure_accum.syliTest_file.id.54_ret_i64@GOTPCREL(%rip), %rax
  	movq	%rax, 16(%rbx)
  	movl	$10, %esi
  	movq	%rbx, %rdi
  	callq	syliTest_file.apply_twice__fn_i64_i64__i64_ret_i64@PLT
  	movq	%rax, %r14
  	movq	%rbx, %rdi
  	callq	syli_rt_object_decr@PLT
  	movq	%rbx, %rdi
  	callq	syli_rt_object_check_release@PLT
  	movq	%r14, %rdi
  	callq	syli_print_i64@PLT
  	addq	$8, %rsp
  	.cfi_def_cfa_offset 24
  	popq	%rbx
  	.cfi_def_cfa_offset 16
  	popq	%r14
  	.cfi_def_cfa_offset 8
  	retq
  .Lfunc_end3:
  	.size	syliTest_file.main, .Lfunc_end3-syliTest_file.main
  	.cfi_endproc
                                          # -- End function
  	.globl	syliTest_file.apply_twice__fn_i64_i64__i64_ret_i64 # -- Begin function syliTest_file.apply_twice__fn_i64_i64__i64_ret_i64
  	.p2align	4, 0x90
  	.type	syliTest_file.apply_twice__fn_i64_i64__i64_ret_i64,@function
  syliTest_file.apply_twice__fn_i64_i64__i64_ret_i64: # @syliTest_file.apply_twice__fn_i64_i64__i64_ret_i64
  	.cfi_startproc
  # %bb.0:                                # %bb0
  	pushq	%rbx
  	.cfi_def_cfa_offset 16
  	.cfi_offset %rbx, -16
  	movq	%rdi, %rbx
  	movq	%rsi, %rdi
  	movq	%rbx, %rsi
  	xorl	%edx, %edx
  	callq	*16(%rbx)
  	movq	%rax, %rdi
  	movq	%rbx, %rsi
  	xorl	%edx, %edx
  	callq	*16(%rbx)
  	popq	%rbx
  	.cfi_def_cfa_offset 8
  	retq
  .Lfunc_end4:
  	.size	syliTest_file.apply_twice__fn_i64_i64__i64_ret_i64, .Lfunc_end4-syliTest_file.apply_twice__fn_i64_i64__i64_ret_i64
  	.cfi_endproc
                                          # -- End function
  	.globl	syliTest_file.id__i64_ret_i64   # -- Begin function syliTest_file.id__i64_ret_i64
  	.p2align	4, 0x90
  	.type	syliTest_file.id__i64_ret_i64,@function
  syliTest_file.id__i64_ret_i64:          # @syliTest_file.id__i64_ret_i64
  	.cfi_startproc
  # %bb.0:                                # %bb0
  	movq	%rdi, %rax
  	retq
  .Lfunc_end5:
  	.size	syliTest_file.id__i64_ret_i64, .Lfunc_end5-syliTest_file.id__i64_ret_i64
  	.cfi_endproc
                                          # -- End function
  	.globl	__make_closure_accum.syliTest_file.id.54_ret_i64 # -- Begin function __make_closure_accum.syliTest_file.id.54_ret_i64
  	.p2align	4, 0x90
  	.type	__make_closure_accum.syliTest_file.id.54_ret_i64,@function
  __make_closure_accum.syliTest_file.id.54_ret_i64: # @__make_closure_accum.syliTest_file.id.54_ret_i64
  	.cfi_startproc
  # %bb.0:                                # %bb0
  	pushq	%rax
  	.cfi_def_cfa_offset 16
  	callq	__wrapper.syliTest_file.id.i64_ret_i64@PLT
  	popq	%rcx
  	.cfi_def_cfa_offset 8
  	retq
  .Lfunc_end6:
  	.size	__make_closure_accum.syliTest_file.id.54_ret_i64, .Lfunc_end6-__make_closure_accum.syliTest_file.id.54_ret_i64
  	.cfi_endproc
                                          # -- End function
  	.globl	__wrapper.syliTest_file.id.i64_ret_i64 # -- Begin function __wrapper.syliTest_file.id.i64_ret_i64
  	.p2align	4, 0x90
  	.type	__wrapper.syliTest_file.id.i64_ret_i64,@function
  __wrapper.syliTest_file.id.i64_ret_i64: # @__wrapper.syliTest_file.id.i64_ret_i64
  	.cfi_startproc
  # %bb.0:                                # %bb0
  	pushq	%rax
  	.cfi_def_cfa_offset 16
  	callq	syliTest_file.id__i64_ret_i64@PLT
  	popq	%rcx
  	.cfi_def_cfa_offset 8
  	retq
  .Lfunc_end7:
  	.size	__wrapper.syliTest_file.id.i64_ret_i64, .Lfunc_end7-__wrapper.syliTest_file.id.i64_ret_i64
  	.cfi_endproc
                                          # -- End function
  	.section	".note.GNU-stack","",@progbits
