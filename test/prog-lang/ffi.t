  $ cat >test_binary.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > fn main () = syli_print_i64(42)
  > EOF
  $ dune exec sylic -- core test_binary.sy > test_binary.core
  $ dune exec sylic -- cir_raw test_binary.sy > test_binary.ir
  $ dune exec sylic -- llvm test_binary.sy > test_binary.ll

  $ cat test_binary.core
  module Test_binary
  let syliTest_binary.main = fun () : unit ->
      syliTest_binary.syli_print_i64(42 : i64) : unit
  

  $ cat test_binary.ir
  module Test_binary :
  ffi_external_functions:
  extern fn syli_print_i64(i64) -> void
  
  
  functions:
  public fn __init.Test_binary() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_binary.main() -> void:
    entry: bb0
  
    bb0:
      %Sy_var0:void = #call_direct syliTest_binary.syli_print_i64 (42:i64)
      return
  end
  
  end

  $ cat test_binary.ll
  declare void @syli_print_i64(i64)
  
  define i32 @syli_startup_program(i32 %argc, ptr %argv) {
  bb0:
    call void @syli_modules_init()
    call void @syliTest_binary.main()
    ret i32 0
  }
  
  define void @syli_modules_init() {
  bb0:
    call void @__init.Test_binary()
    ret void
  }
  
  define void @__init.Test_binary() {
  bb0:
    ret void
  }
  
  define void @syliTest_binary.main() {
  bb0:
    call void @syli_print_i64(i64 42)
    ret void
  }
  
