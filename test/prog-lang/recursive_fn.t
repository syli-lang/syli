  $ cat >test_file.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > let rec factorial n =
  >   if n == 0 then
  >     1
  >   else
  >     n * factorial (n - 1)
  > fn main () = syli_print_i64 (factorial 5)
  > EOF
  $ dune exec sylic -- core test_file.sy > test_file.core
  $ dune exec sylic -- cir test_file.sy > test_file.ir
  $ dune exec sylic -- llvm test_file.sy > test_file.ll

  $ cat test_file.core
  module Test_file
  let rec syliTest_file.factorial = fun (n) : i64 ->
      if (n : i64 == 0 : i64) : bool
        1 : i64
      else
        (n : i64 * syliTest_file.factorial((n : i64 - 1 : i64) : i64) : i64) : i64
  
  let syliTest_file.main = fun () : unit ->
      syliTest_file.syli_print_i64(syliTest_file.factorial(5 : i64) : i64) : unit
  

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
      %Sy_var0:i64 = #call_direct syliTest_file.factorial (5:i64)
      %Sy_var1:void = #call_direct syliTest_file.syli_print_i64 (%Sy_var0:i64)
      return
  end
  
  public fn syliTest_file.factorial(%n:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:bool = %n:i64 == 0:i64
      cond_br %Sy_var0:bool, bb1, bb2
  
    bb2:
      %Sy_var2:i64 = %n:i64 - 1:i64
      %Sy_var3:i64 = #call_direct syliTest_file.factorial (%Sy_var2:i64)
      %Sy_var4:i64 = %n:i64 * %Sy_var3:i64
      %Sy_var1:i64 = move(%Sy_var4:i64)
      goto bb3
  
    bb1:
      %Sy_var1:i64 = move(1:i64)
      goto bb3
  
    bb3:
  
      return %Sy_var1:i64
  end
  
  end

  $ cat test_file.ll
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
    %Sy_var0 = call i64 @syliTest_file.factorial(i64 5)
    call void @syli_print_i64(i64 %Sy_var0)
    ret void
  }
  
  define i64 @syliTest_file.factorial(i64 %n) {
  bb0:
    %Sy_var1 = alloca i64
    %Sy_var0 = icmp eq i64 %n, 0
    br i1 %Sy_var0, label %bb1, label %bb2
  bb2:
    %Sy_var2 = sub i64 %n, 1
    %Sy_var3 = call i64 @syliTest_file.factorial(i64 %Sy_var2)
    %Sy_var4 = mul i64 %n, %Sy_var3
    store i64 %Sy_var4, ptr %Sy_var1
    br label %bb3
  bb1:
    store i64 1, ptr %Sy_var1
    br label %bb3
  bb3:
    %Sy_tmp0 = load i64, ptr %Sy_var1
    ret i64 %Sy_tmp0
  }
  

  $ clang -O3 -S --target=x86_64-pc-linux-gnu test_file.ll
  warning: overriding the module target triple with x86_64-pc-linux-gnu [-Woverride-module]
  1 warning generated.
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
  	movl	$120, %edi
  	callq	syli_print_i64@PLT
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
  	movl	$120, %edi
  	jmp	syli_print_i64@PLT              # TAILCALL
  .Lfunc_end3:
  	.size	syliTest_file.main, .Lfunc_end3-syliTest_file.main
  	.cfi_endproc
                                          # -- End function
  	.globl	syliTest_file.factorial         # -- Begin function syliTest_file.factorial
  	.p2align	4, 0x90
  	.type	syliTest_file.factorial,@function
  syliTest_file.factorial:                # @syliTest_file.factorial
  # %bb.0:                                # %bb0
  	testq	%rdi, %rdi
  	je	.LBB4_1
  # %bb.2:                                # %bb2.preheader
  	movl	%edi, %ecx
  	andl	$7, %ecx
  	cmpq	$8, %rdi
  	jae	.LBB4_4
  # %bb.3:
  	movl	$1, %eax
  	testq	%rcx, %rcx
  	jne	.LBB4_8
  	jmp	.LBB4_9
  .LBB4_1:
  	movl	$1, %eax
  	retq
  .LBB4_4:                                # %bb2.preheader.new
  	movq	%rdi, %rdx
  	andq	$-8, %rdx
  	negq	%rdx
  	movl	$1, %eax
  	xorl	%esi, %esi
  	.p2align	4, 0x90
  .LBB4_5:                                # %bb2
                                          # =>This Inner Loop Header: Depth=1
  	leaq	(%rdi,%rsi), %r8
  	imulq	%rax, %r8
  	leaq	(%rdi,%rsi), %rax
  	decq	%rax
  	leaq	(%rdi,%rsi), %r9
  	addq	$-2, %r9
  	imulq	%rax, %r9
  	imulq	%r8, %r9
  	leaq	(%rdi,%rsi), %rax
  	addq	$-3, %rax
  	leaq	(%rdi,%rsi), %r8
  	addq	$-4, %r8
  	imulq	%rax, %r8
  	leaq	(%rdi,%rsi), %r10
  	addq	$-5, %r10
  	imulq	%r8, %r10
  	imulq	%r9, %r10
  	leaq	(%rdi,%rsi), %r8
  	addq	$-6, %r8
  	leaq	(%rdi,%rsi), %rax
  	addq	$-7, %rax
  	imulq	%r8, %rax
  	imulq	%r10, %rax
  	addq	$-8, %rsi
  	cmpq	%rsi, %rdx
  	jne	.LBB4_5
  # %bb.6:                                # %bb3.loopexit.unr-lcssa.loopexit
  	addq	%rsi, %rdi
  	testq	%rcx, %rcx
  	je	.LBB4_9
  	.p2align	4, 0x90
  .LBB4_8:                                # %bb2.epil
                                          # =>This Inner Loop Header: Depth=1
  	imulq	%rdi, %rax
  	decq	%rdi
  	decq	%rcx
  	jne	.LBB4_8
  .LBB4_9:                                # %bb3
  	retq
  .Lfunc_end4:
  	.size	syliTest_file.factorial, .Lfunc_end4-syliTest_file.factorial
                                          # -- End function
  	.section	".note.GNU-stack","",@progbits
  	.addrsig
