LLVM codegen tests — Syli source to LLVM IR text

Integer literal emits an i64 function:
  $ cat >test_int.sy <<EOF
  > let x = 42
  > EOF
  $ dune exec sylic -- llvm test_int.sy
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
  

Boolean literals emit i1 functions:
  $ cat >test_bool.sy <<EOF
  > let p = true
  > let q = false
  > EOF
  $ dune exec sylic -- llvm test_bool.sy
  @syliTest_bool.p = global i1 true
  @syliTest_bool.q = global i1 false
  
  define void @__init.Test_bool() {
  bb0:
    %__init_tmp_0 = call i1 @__init_global.syliTest_bool.p()
    store i1 %__init_tmp_0, ptr @syliTest_bool.p
    %__init_tmp_1 = call i1 @__init_global.syliTest_bool.q()
    store i1 %__init_tmp_1, ptr @syliTest_bool.q
    ret void
  }
  
  define i1 @__init_global.syliTest_bool.q() {
  bb0:
    ret i1 false
  }
  
  define i1 @__init_global.syliTest_bool.p() {
  bb0:
    ret i1 true
  }
  

String literal emits an i8* return:
  $ cat >test_str.sy <<EOF
  > let s = "hello"
  > EOF
  $ dune exec sylic -- llvm test_str.sy
  @syliTest_str.s = global { ptr, i64 } zeroinitializer
  @__str.1 = global [5 x i8] c"hello"
  
  define void @__init.Test_str() {
  bb0:
    %__init_tmp_0 = call { ptr, i64 } @__init_global.syliTest_str.s()
    store { ptr, i64 } %__init_tmp_0, ptr @syliTest_str.s
    ret void
  }
  
  define { ptr, i64 } @__init_global.syliTest_str.s() {
  bb0:
    %Sy_tmp0 = getelementptr i8, ptr @__str.1, i32 0
    %Sy_tmp1 = insertvalue { ptr, i64 } zeroinitializer, ptr %Sy_tmp0, 0
    %Sy_tmp2 = insertvalue { ptr, i64 } %Sy_tmp1, i64 5, 1
    ret { ptr, i64 } %Sy_tmp2
  }
  

Arithmetic operations emit the corresponding LLVM instructions:
  $ cat >test_arith.sy <<EOF
  > let a = 5 + 3
  > let b = 10 - 2
  > let c = 4 * 6
  > let d = 20 / 4
  > EOF
  $ dune exec sylic -- llvm test_arith.sy
  @syliTest_arith.a = global i64 zeroinitializer
  @syliTest_arith.b = global i64 zeroinitializer
  @syliTest_arith.c = global i64 zeroinitializer
  @syliTest_arith.d = global i64 zeroinitializer
  
  define void @__init.Test_arith() {
  bb0:
    %__init_tmp_0 = call i64 @__init_global.syliTest_arith.a()
    store i64 %__init_tmp_0, ptr @syliTest_arith.a
    %__init_tmp_1 = call i64 @__init_global.syliTest_arith.b()
    store i64 %__init_tmp_1, ptr @syliTest_arith.b
    %__init_tmp_2 = call i64 @__init_global.syliTest_arith.c()
    store i64 %__init_tmp_2, ptr @syliTest_arith.c
    %__init_tmp_3 = call i64 @__init_global.syliTest_arith.d()
    store i64 %__init_tmp_3, ptr @syliTest_arith.d
    ret void
  }
  
  define i64 @__init_global.syliTest_arith.d() {
  bb0:
    %Sy_var0 = sdiv i64 20, 4
    ret i64 %Sy_var0
  }
  
  define i64 @__init_global.syliTest_arith.c() {
  bb0:
    %Sy_var0 = mul i64 4, 6
    ret i64 %Sy_var0
  }
  
  define i64 @__init_global.syliTest_arith.b() {
  bb0:
    %Sy_var0 = sub i64 10, 2
    ret i64 %Sy_var0
  }
  
  define i64 @__init_global.syliTest_arith.a() {
  bb0:
    %Sy_var0 = add i64 5, 3
    ret i64 %Sy_var0
  }
  


Comparison operations emit icmp instructions:
  $ cat >test_cmp.sy <<EOF
  > let eq = 5 == 5
  > let lt = 2 < 5
  > EOF
  $ dune exec sylic -- llvm test_cmp.sy
  @syliTest_cmp.eq = global i1 zeroinitializer
  @syliTest_cmp.lt = global i1 zeroinitializer
  
  define void @__init.Test_cmp() {
  bb0:
    %__init_tmp_0 = call i1 @__init_global.syliTest_cmp.eq()
    store i1 %__init_tmp_0, ptr @syliTest_cmp.eq
    %__init_tmp_1 = call i1 @__init_global.syliTest_cmp.lt()
    store i1 %__init_tmp_1, ptr @syliTest_cmp.lt
    ret void
  }
  
  define i1 @__init_global.syliTest_cmp.lt() {
  bb0:
    %Sy_var0 = icmp slt i64 2, 5
    ret i1 %Sy_var0
  }
  
  define i1 @__init_global.syliTest_cmp.eq() {
  bb0:
    %Sy_var0 = icmp eq i64 5, 5
    ret i1 %Sy_var0
  }
  

Simple Function:
  $ cat >test_fn.sy <<EOF
  > fn add x y = x + 20 + y
  > EOF
  $ dune exec sylic -- llvm test_fn.sy
  define void @__init.Test_fn() {
  bb0:
    ret void
  }
  
  define i64 @syliTest_fn.add(i64 %x, i64 %y) {
  bb0:
    %Sy_var0 = add i64 %x, 20
    %Sy_var1 = add i64 %Sy_var0, %y
    ret i64 %Sy_var1
  }
  

Tuple emits syli_object_create and syli_object_set runtime calls:
  $ cat >test_tuple.sy <<EOF
  > let pair = (1, 2)
  > EOF
  $ dune exec sylic -- llvm test_tuple.sy
  Fatal error: exception Middle_end__Lower_ast_to_core.Desugar_error(":11-17: tuple expressions are not lowered to Core yet")
  ***** UNREACHABLE *****

Triple tuple emits three object_set calls:
  $ cat >test_triple.sy <<EOF
  > let triple = (true, 42, "x")
  > EOF
  ***** UNREACHABLE *****
  $ dune exec sylic -- llvm test_triple.sy
  ***** UNREACHABLE *****

Type error propagates from typing phase:
  $ cat >test_tyerr.sy <<EOF
  > let x = 1 + true
  > EOF
  ***** UNREACHABLE *****
  $ dune exec sylic -- llvm test_tyerr.sy 2>&1
  ***** UNREACHABLE *****

Collection literals are not yet lowered (unsupported):
  $ cat >test_arr.sy <<EOF
  > let arr = [1, 2, 3]
  > EOF
  ***** UNREACHABLE *****
  $ dune exec sylic -- llvm test_arr.sy 2>&1
  ***** UNREACHABLE *****

Missing file produces an error:
  $ dune exec sylic -- llvm no_such_file.sy 2>&1
  ***** UNREACHABLE *****
