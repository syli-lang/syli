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
  

  $ clang -c test_file.ll -o /dev/null 2>/dev/null
