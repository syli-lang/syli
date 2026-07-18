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
    %Sy_tmp0 = getelementptr { i64, i64, [0 x i64] }, ptr %Sy_var0, i32 0, i32 2, i64 0
    store i64 10, ptr %Sy_tmp0
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr %Sy_var0, i32 0, i32 2, i64 1
    store i64 30, ptr %Sy_tmp1
    %Sy_tmp2 = getelementptr { i64, i64, [0 x i64] }, ptr %Sy_var0, i32 0, i32 2, i64 1
    %Sy_var1 = load i64, ptr %Sy_tmp2
    call void @syli_rt_object_decr(ptr %Sy_var0)
    call void @syli_rt_object_check_release(ptr %Sy_var0)
    call void @syli_print_i64(i64 %Sy_var1)
    ret void
  }
  


  $ opt -passes=mem2reg test_e2e_print.ll -S -o test_e2e_print_opt.ll
  $ cat test_e2e_print_opt.ll
  ; ModuleID = 'test_e2e_print.ll'
  source_filename = "test_e2e_print.ll"
  
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
    %Sy_tmp0 = getelementptr { i64, i64, [0 x i64] }, ptr %Sy_var0, i32 0, i32 2, i64 0
    store i64 10, ptr %Sy_tmp0, align 4
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr %Sy_var0, i32 0, i32 2, i64 1
    store i64 30, ptr %Sy_tmp1, align 4
    %Sy_tmp2 = getelementptr { i64, i64, [0 x i64] }, ptr %Sy_var0, i32 0, i32 2, i64 1
    %Sy_var1 = load i64, ptr %Sy_tmp2, align 4
    call void @syli_rt_object_decr(ptr %Sy_var0)
    call void @syli_rt_object_check_release(ptr %Sy_var0)
    call void @syli_print_i64(i64 %Sy_var1)
    ret void
  }
  $ opt --O2 -S test_e2e_print_opt.ll -o test_e2e_print_opt2.ll
  $ cat test_e2e_print_opt2.ll
  ; ModuleID = 'test_e2e_print_opt.ll'
  source_filename = "test_e2e_print.ll"
  
  declare void @syli_rt_gc_cycle() local_unnamed_addr
  
  declare void @syli_rt_object_check_release(ptr) local_unnamed_addr
  
  declare void @syli_rt_object_decr(ptr) local_unnamed_addr
  
  declare ptr @syli_rt_rc_alloc_object(i64, i32, i64) local_unnamed_addr
  
  declare void @syli_print_i64(i64) local_unnamed_addr
  
  define noundef i32 @syli_startup_program(i32 %argc, ptr nocapture readnone %argv) local_unnamed_addr {
  bb0:
    tail call void @syli_rt_gc_cycle()
    %Sy_var0.i = tail call ptr @syli_rt_rc_alloc_object(i64 2305843009213693954, i32 1, i64 2)
    %Sy_tmp0.i = getelementptr i8, ptr %Sy_var0.i, i64 16
    store i64 10, ptr %Sy_tmp0.i, align 4
    %Sy_tmp1.i = getelementptr i8, ptr %Sy_var0.i, i64 24
    store i64 30, ptr %Sy_tmp1.i, align 4
    tail call void @syli_rt_object_decr(ptr %Sy_var0.i)
    tail call void @syli_rt_object_check_release(ptr %Sy_var0.i)
    tail call void @syli_print_i64(i64 30)
    ret i32 0
  }
  
  ; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
  define void @syli_modules_init() local_unnamed_addr #0 {
  bb0:
    ret void
  }
  
  ; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
  define void @__init.Test_e2e_print() local_unnamed_addr #0 {
  bb0:
    ret void
  }
  
  define void @syliTest_e2e_print.main() local_unnamed_addr {
  bb0:
    tail call void @syli_rt_gc_cycle()
    %Sy_var0 = tail call ptr @syli_rt_rc_alloc_object(i64 2305843009213693954, i32 1, i64 2)
    %Sy_tmp0 = getelementptr i8, ptr %Sy_var0, i64 16
    store i64 10, ptr %Sy_tmp0, align 4
    %Sy_tmp1 = getelementptr i8, ptr %Sy_var0, i64 24
    store i64 30, ptr %Sy_tmp1, align 4
    tail call void @syli_rt_object_decr(ptr %Sy_var0)
    tail call void @syli_rt_object_check_release(ptr %Sy_var0)
    tail call void @syli_print_i64(i64 30)
    ret void
  }
  
  attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) }

  $ opt --O3 -S test_e2e_print_opt.ll -o test_e2e_print_opt3.ll
  $ cat test_e2e_print_opt3.ll
  ; ModuleID = 'test_e2e_print_opt.ll'
  source_filename = "test_e2e_print.ll"
  
  declare void @syli_rt_gc_cycle() local_unnamed_addr
  
  declare void @syli_rt_object_check_release(ptr) local_unnamed_addr
  
  declare void @syli_rt_object_decr(ptr) local_unnamed_addr
  
  declare ptr @syli_rt_rc_alloc_object(i64, i32, i64) local_unnamed_addr
  
  declare void @syli_print_i64(i64) local_unnamed_addr
  
  define noundef i32 @syli_startup_program(i32 %argc, ptr nocapture readnone %argv) local_unnamed_addr {
  bb0:
    tail call void @syli_rt_gc_cycle()
    %Sy_var0.i = tail call ptr @syli_rt_rc_alloc_object(i64 2305843009213693954, i32 1, i64 2)
    %Sy_tmp0.i = getelementptr i8, ptr %Sy_var0.i, i64 16
    store i64 10, ptr %Sy_tmp0.i, align 4
    %Sy_tmp1.i = getelementptr i8, ptr %Sy_var0.i, i64 24
    store i64 30, ptr %Sy_tmp1.i, align 4
    tail call void @syli_rt_object_decr(ptr %Sy_var0.i)
    tail call void @syli_rt_object_check_release(ptr %Sy_var0.i)
    tail call void @syli_print_i64(i64 30)
    ret i32 0
  }
  
  ; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
  define void @syli_modules_init() local_unnamed_addr #0 {
  bb0:
    ret void
  }
  
  ; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
  define void @__init.Test_e2e_print() local_unnamed_addr #0 {
  bb0:
    ret void
  }
  
  define void @syliTest_e2e_print.main() local_unnamed_addr {
  bb0:
    tail call void @syli_rt_gc_cycle()
    %Sy_var0 = tail call ptr @syli_rt_rc_alloc_object(i64 2305843009213693954, i32 1, i64 2)
    %Sy_tmp0 = getelementptr i8, ptr %Sy_var0, i64 16
    store i64 10, ptr %Sy_tmp0, align 4
    %Sy_tmp1 = getelementptr i8, ptr %Sy_var0, i64 24
    store i64 30, ptr %Sy_tmp1, align 4
    tail call void @syli_rt_object_decr(ptr %Sy_var0)
    tail call void @syli_rt_object_check_release(ptr %Sy_var0)
    tail call void @syli_print_i64(i64 30)
    ret void
  }
  
  attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) }


  $ llc test_e2e_print_opt3.ll
  $ cat test_e2e_print_opt3.s
  	.text
  	.file	"test_e2e_print.ll"
  	.globl	syli_startup_program            # -- Begin function syli_startup_program
  	.p2align	4, 0x90
  	.type	syli_startup_program,@function
  syli_startup_program:                   # @syli_startup_program
  	.cfi_startproc
  # %bb.0:                                # %bb0
  	pushq	%rbx
  	.cfi_def_cfa_offset 16
  	.cfi_offset %rbx, -16
  	callq	syli_rt_gc_cycle@PLT
  	movabsq	$2305843009213693954, %rdi      # imm = 0x2000000000000002
  	movl	$2, %edx
  	movl	$1, %esi
  	callq	syli_rt_rc_alloc_object@PLT
  	movq	%rax, %rbx
  	movq	$10, 16(%rax)
  	movq	$30, 24(%rax)
  	movq	%rax, %rdi
  	callq	syli_rt_object_decr@PLT
  	movq	%rbx, %rdi
  	callq	syli_rt_object_check_release@PLT
  	movl	$30, %edi
  	callq	syli_print_i64@PLT
  	xorl	%eax, %eax
  	popq	%rbx
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
  	.globl	__init.Test_e2e_print           # -- Begin function __init.Test_e2e_print
  	.p2align	4, 0x90
  	.type	__init.Test_e2e_print,@function
  __init.Test_e2e_print:                  # @__init.Test_e2e_print
  # %bb.0:                                # %bb0
  	retq
  .Lfunc_end2:
  	.size	__init.Test_e2e_print, .Lfunc_end2-__init.Test_e2e_print
                                          # -- End function
  	.globl	syliTest_e2e_print.main         # -- Begin function syliTest_e2e_print.main
  	.p2align	4, 0x90
  	.type	syliTest_e2e_print.main,@function
  syliTest_e2e_print.main:                # @syliTest_e2e_print.main
  	.cfi_startproc
  # %bb.0:                                # %bb0
  	pushq	%rbx
  	.cfi_def_cfa_offset 16
  	.cfi_offset %rbx, -16
  	callq	syli_rt_gc_cycle@PLT
  	movabsq	$2305843009213693954, %rdi      # imm = 0x2000000000000002
  	movl	$2, %edx
  	movl	$1, %esi
  	callq	syli_rt_rc_alloc_object@PLT
  	movq	%rax, %rbx
  	movq	$10, 16(%rax)
  	movq	$30, 24(%rax)
  	movq	%rax, %rdi
  	callq	syli_rt_object_decr@PLT
  	movq	%rbx, %rdi
  	callq	syli_rt_object_check_release@PLT
  	movl	$30, %edi
  	popq	%rbx
  	.cfi_def_cfa_offset 8
  	jmp	syli_print_i64@PLT              # TAILCALL
  .Lfunc_end3:
  	.size	syliTest_e2e_print.main, .Lfunc_end3-syliTest_e2e_print.main
  	.cfi_endproc
                                          # -- End function
  	.section	".note.GNU-stack","",@progbits
