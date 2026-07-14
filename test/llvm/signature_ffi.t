Signature with external declaration emits an external declaration in LLVM IR:
  $ cat >test_int.sy <<EOF
  > signature:
  >   extern print_int : int -> unit = "print_int"
  > end
  > let x = 42
  > EOF
  $ dune exec sylic -- llvm test_int.sy
  declare void @print_int(ptr)
  
  @syliTest_int.x = global i64 42
  
  define void @__init.Test_int() {
  bb0:
    %__init_tmp_0 = call i64 @__init_global.syliTest_int.x()
    store i64 %__init_tmp_0, ptr @syliTest_int.x
    ret void
  }
  
  define i64 @__init_global.syliTest_int.x() {
  bb0:
    ret i64 42
  }
  
