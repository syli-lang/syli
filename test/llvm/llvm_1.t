LLVM codegen tests — Syli source to LLVM IR text

Integer literal emits an i64 function:
  $ cat >test_int.sy <<EOF
  > let x = 42
  > EOF
  $ dune exec sylic -- llvm test_int.sy
  declare void @syli_rt_ownership_decr(ptr addrspace(1))
  declare void @syli_rt_ownership_incr(ptr addrspace(1))
  
  @syliTest_int.x = global i64 42
  
  define i32 @syli_startup_program() gc "statepoint-example" {
  bb0:
    call void @syli_modules_init()
    ret i32 0
  }
  
  define void @syli_modules_init() gc "statepoint-example" {
  bb0:
    call void @__init.Test_int()
    ret void
  }
  
  define void @__init.Test_int() gc "statepoint-example" {
  bb0:
    %__sy_cir_init_tmp_0 = call i64 @__init_global.syliTest_int.x()
    store i64 %__sy_cir_init_tmp_0, ptr @syliTest_int.x
    ret void
  }
  
  define i64 @__init_global.syliTest_int.x() gc "statepoint-example" {
  bb0:
    ret i64 42
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -4
    %r = inttoptr i64 %u to ptr addrspace(1)
    ret ptr addrspace(1) %r
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_borrow(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -2
    %r = inttoptr i64 %u to ptr addrspace(1)
    ret ptr addrspace(1) %r
  }
  
  define void @syli_inlinable_ownership_release(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 3
    %is_own = icmp eq i64 %tag, 1
    br i1 %is_own, label %own, label %done
  own:
    call void @syli_rt_ownership_decr(ptr addrspace(1) %p)
    ret void
  done:
    ret void
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_own(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 3
    %is_borrow = icmp eq i64 %tag, 0
    br i1 %is_borrow, label %promote, label %done
  promote:
    %r = or i64 %pi, 1
    %rp = inttoptr i64 %r to ptr addrspace(1)
    call void @syli_rt_ownership_incr(ptr addrspace(1) %rp)
    ret ptr addrspace(1) %rp
  done:
    ret ptr addrspace(1) %p
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_share(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 2
    %is_always = icmp ne i64 %tag, 0
    br i1 %is_always, label %done, label %promote
  promote:
    %r = or i64 %pi, 1
    %rp = inttoptr i64 %r to ptr addrspace(1)
    call void @syli_rt_ownership_incr(ptr addrspace(1) %rp)
    ret ptr addrspace(1) %rp
  done:
    ret ptr addrspace(1) %p
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_make_always_borrow(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -4
    %r = or i64 %u, 2
    %rp = inttoptr i64 %r to ptr addrspace(1)
    ret ptr addrspace(1) %rp
  }
  

Boolean literals emit i1 functions:
  $ cat >test_bool.sy <<EOF
  > let p = true
  > let q = false
  > EOF
  $ dune exec sylic -- llvm test_bool.sy
  declare void @syli_rt_ownership_decr(ptr addrspace(1))
  declare void @syli_rt_ownership_incr(ptr addrspace(1))
  
  @syliTest_bool.p = global i1 true
  @syliTest_bool.q = global i1 false
  
  define i32 @syli_startup_program() gc "statepoint-example" {
  bb0:
    call void @syli_modules_init()
    ret i32 0
  }
  
  define void @syli_modules_init() gc "statepoint-example" {
  bb0:
    call void @__init.Test_bool()
    ret void
  }
  
  define void @__init.Test_bool() gc "statepoint-example" {
  bb0:
    %__sy_cir_init_tmp_0 = call i1 @__init_global.syliTest_bool.p()
    store i1 %__sy_cir_init_tmp_0, ptr @syliTest_bool.p
    %__sy_cir_init_tmp_1 = call i1 @__init_global.syliTest_bool.q()
    store i1 %__sy_cir_init_tmp_1, ptr @syliTest_bool.q
    ret void
  }
  
  define i1 @__init_global.syliTest_bool.q() gc "statepoint-example" {
  bb0:
    ret i1 false
  }
  
  define i1 @__init_global.syliTest_bool.p() gc "statepoint-example" {
  bb0:
    ret i1 true
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -4
    %r = inttoptr i64 %u to ptr addrspace(1)
    ret ptr addrspace(1) %r
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_borrow(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -2
    %r = inttoptr i64 %u to ptr addrspace(1)
    ret ptr addrspace(1) %r
  }
  
  define void @syli_inlinable_ownership_release(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 3
    %is_own = icmp eq i64 %tag, 1
    br i1 %is_own, label %own, label %done
  own:
    call void @syli_rt_ownership_decr(ptr addrspace(1) %p)
    ret void
  done:
    ret void
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_own(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 3
    %is_borrow = icmp eq i64 %tag, 0
    br i1 %is_borrow, label %promote, label %done
  promote:
    %r = or i64 %pi, 1
    %rp = inttoptr i64 %r to ptr addrspace(1)
    call void @syli_rt_ownership_incr(ptr addrspace(1) %rp)
    ret ptr addrspace(1) %rp
  done:
    ret ptr addrspace(1) %p
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_share(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 2
    %is_always = icmp ne i64 %tag, 0
    br i1 %is_always, label %done, label %promote
  promote:
    %r = or i64 %pi, 1
    %rp = inttoptr i64 %r to ptr addrspace(1)
    call void @syli_rt_ownership_incr(ptr addrspace(1) %rp)
    ret ptr addrspace(1) %rp
  done:
    ret ptr addrspace(1) %p
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_make_always_borrow(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -4
    %r = or i64 %u, 2
    %rp = inttoptr i64 %r to ptr addrspace(1)
    ret ptr addrspace(1) %rp
  }
  

String literal emits an i8* return:
  $ cat >test_str.sy <<EOF
  > let s = "hello"
  > EOF
  $ dune exec sylic -- llvm test_str.sy
  declare void @syli_rt_ownership_decr(ptr addrspace(1))
  declare void @syli_rt_ownership_incr(ptr addrspace(1))
  
  @syliTest_str.s = global ptr addrspace(1) zeroinitializer
  @__str.1 = global { i64, i64, [8 x i8] } { i64 -9223372036854775807, i64 0, [8 x i8] c"hello\00\00\02" }
  
  define i32 @syli_startup_program() gc "statepoint-example" {
  bb0:
    call void @syli_modules_init()
    ret i32 0
  }
  
  define void @syli_modules_init() gc "statepoint-example" {
  bb0:
    call void @__init.Test_str()
    ret void
  }
  
  define void @__init.Test_str() gc "statepoint-example" {
  bb0:
    %__sy_cir_init_tmp_0 = call ptr addrspace(1) @__init_global.syliTest_str.s()
    store ptr addrspace(1) %__sy_cir_init_tmp_0, ptr @syliTest_str.s
    ret void
  }
  
  define ptr addrspace(1) @__init_global.syliTest_str.s() gc "statepoint-example" {
  bb0:
    %Sy_llvm_tmp_0 = ptrtoint ptr @__str.1 to i64
    %Sy_llvm_tmp_1 = add i64 %Sy_llvm_tmp_0, 2
    %Sy_llvm_tmp_2 = inttoptr i64 %Sy_llvm_tmp_1 to ptr addrspace(1)
    ret ptr addrspace(1) %Sy_llvm_tmp_2
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -4
    %r = inttoptr i64 %u to ptr addrspace(1)
    ret ptr addrspace(1) %r
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_borrow(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -2
    %r = inttoptr i64 %u to ptr addrspace(1)
    ret ptr addrspace(1) %r
  }
  
  define void @syli_inlinable_ownership_release(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 3
    %is_own = icmp eq i64 %tag, 1
    br i1 %is_own, label %own, label %done
  own:
    call void @syli_rt_ownership_decr(ptr addrspace(1) %p)
    ret void
  done:
    ret void
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_own(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 3
    %is_borrow = icmp eq i64 %tag, 0
    br i1 %is_borrow, label %promote, label %done
  promote:
    %r = or i64 %pi, 1
    %rp = inttoptr i64 %r to ptr addrspace(1)
    call void @syli_rt_ownership_incr(ptr addrspace(1) %rp)
    ret ptr addrspace(1) %rp
  done:
    ret ptr addrspace(1) %p
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_share(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 2
    %is_always = icmp ne i64 %tag, 0
    br i1 %is_always, label %done, label %promote
  promote:
    %r = or i64 %pi, 1
    %rp = inttoptr i64 %r to ptr addrspace(1)
    call void @syli_rt_ownership_incr(ptr addrspace(1) %rp)
    ret ptr addrspace(1) %rp
  done:
    ret ptr addrspace(1) %p
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_make_always_borrow(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -4
    %r = or i64 %u, 2
    %rp = inttoptr i64 %r to ptr addrspace(1)
    ret ptr addrspace(1) %rp
  }
  

Arithmetic operations emit the corresponding LLVM instructions:
  $ cat >test_arith.sy <<EOF
  > primitive (+) : i64 -> i64 -> i64 = "add"
  > primitive (*) : i64 -> i64 -> i64 = "mul"
  > primitive (-) : i64 -> i64 -> i64 = "sub"
  > primitive (/) : i64 -> i64 -> i64 = "div"
  > let a = 5 + 3
  > let b = 10 - 2
  > let c = 4 * 6
  > let d = 20 / 4
  > EOF
  $ dune exec sylic -- llvm test_arith.sy
  declare void @syli_rt_ownership_decr(ptr addrspace(1))
  declare void @syli_rt_ownership_incr(ptr addrspace(1))
  
  @syliTest_arith.a = global i64 zeroinitializer
  @syliTest_arith.b = global i64 zeroinitializer
  @syliTest_arith.c = global i64 zeroinitializer
  @syliTest_arith.d = global i64 zeroinitializer
  
  define i32 @syli_startup_program() gc "statepoint-example" {
  bb0:
    call void @syli_modules_init()
    ret i32 0
  }
  
  define void @syli_modules_init() gc "statepoint-example" {
  bb0:
    call void @__init.Test_arith()
    ret void
  }
  
  define void @__init.Test_arith() gc "statepoint-example" {
  bb0:
    %__sy_cir_init_tmp_0 = call i64 @__init_global.syliTest_arith.a()
    store i64 %__sy_cir_init_tmp_0, ptr @syliTest_arith.a
    %__sy_cir_init_tmp_1 = call i64 @__init_global.syliTest_arith.b()
    store i64 %__sy_cir_init_tmp_1, ptr @syliTest_arith.b
    %__sy_cir_init_tmp_2 = call i64 @__init_global.syliTest_arith.c()
    store i64 %__sy_cir_init_tmp_2, ptr @syliTest_arith.c
    %__sy_cir_init_tmp_3 = call i64 @__init_global.syliTest_arith.d()
    store i64 %__sy_cir_init_tmp_3, ptr @syliTest_arith.d
    ret void
  }
  
  define i64 @__init_global.syliTest_arith.d() gc "statepoint-example" {
  bb0:
    %Sy_cir_var_0 = call i64 @"syliTest_arith./"(i64 20, i64 4)
    ret i64 %Sy_cir_var_0
  }
  
  define i64 @__init_global.syliTest_arith.c() gc "statepoint-example" {
  bb0:
    %Sy_cir_var_0 = call i64 @"syliTest_arith.*"(i64 4, i64 6)
    ret i64 %Sy_cir_var_0
  }
  
  define i64 @__init_global.syliTest_arith.b() gc "statepoint-example" {
  bb0:
    %Sy_cir_var_0 = call i64 @"syliTest_arith.-"(i64 10, i64 2)
    ret i64 %Sy_cir_var_0
  }
  
  define i64 @__init_global.syliTest_arith.a() gc "statepoint-example" {
  bb0:
    %Sy_cir_var_0 = call i64 @"syliTest_arith.+"(i64 5, i64 3)
    ret i64 %Sy_cir_var_0
  }
  
  define i64 @"syliTest_arith.+"(i64 %x, i64 %y) gc "statepoint-example" {
  bb0:
    %Sy_prim_result = add i64 %x, %y
    ret i64 %Sy_prim_result
  }
  
  define i64 @"syliTest_arith.*"(i64 %x, i64 %y) gc "statepoint-example" {
  bb0:
    %Sy_prim_result = mul i64 %x, %y
    ret i64 %Sy_prim_result
  }
  
  define i64 @"syliTest_arith.-"(i64 %x, i64 %y) gc "statepoint-example" {
  bb0:
    %Sy_prim_result = sub i64 %x, %y
    ret i64 %Sy_prim_result
  }
  
  define i64 @"syliTest_arith./"(i64 %x, i64 %y) gc "statepoint-example" {
  bb0:
    %Sy_prim_result = sdiv i64 %x, %y
    ret i64 %Sy_prim_result
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -4
    %r = inttoptr i64 %u to ptr addrspace(1)
    ret ptr addrspace(1) %r
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_borrow(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -2
    %r = inttoptr i64 %u to ptr addrspace(1)
    ret ptr addrspace(1) %r
  }
  
  define void @syli_inlinable_ownership_release(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 3
    %is_own = icmp eq i64 %tag, 1
    br i1 %is_own, label %own, label %done
  own:
    call void @syli_rt_ownership_decr(ptr addrspace(1) %p)
    ret void
  done:
    ret void
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_own(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 3
    %is_borrow = icmp eq i64 %tag, 0
    br i1 %is_borrow, label %promote, label %done
  promote:
    %r = or i64 %pi, 1
    %rp = inttoptr i64 %r to ptr addrspace(1)
    call void @syli_rt_ownership_incr(ptr addrspace(1) %rp)
    ret ptr addrspace(1) %rp
  done:
    ret ptr addrspace(1) %p
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_share(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 2
    %is_always = icmp ne i64 %tag, 0
    br i1 %is_always, label %done, label %promote
  promote:
    %r = or i64 %pi, 1
    %rp = inttoptr i64 %r to ptr addrspace(1)
    call void @syli_rt_ownership_incr(ptr addrspace(1) %rp)
    ret ptr addrspace(1) %rp
  done:
    ret ptr addrspace(1) %p
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_make_always_borrow(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -4
    %r = or i64 %u, 2
    %rp = inttoptr i64 %r to ptr addrspace(1)
    ret ptr addrspace(1) %rp
  }
  


Comparison operations emit icmp instructions:
  $ cat >test_cmp.sy <<EOF
  > primitive (==) : i64 -> i64 -> bool = "eq"
  > primitive (<) : i64 -> i64 -> bool = "lt"
  > let eq = 5 == 5
  > let lt = 2 < 5
  > EOF
  $ dune exec sylic -- llvm test_cmp.sy
  declare void @syli_rt_ownership_decr(ptr addrspace(1))
  declare void @syli_rt_ownership_incr(ptr addrspace(1))
  
  @syliTest_cmp.eq = global i1 zeroinitializer
  @syliTest_cmp.lt = global i1 zeroinitializer
  
  define i32 @syli_startup_program() gc "statepoint-example" {
  bb0:
    call void @syli_modules_init()
    ret i32 0
  }
  
  define void @syli_modules_init() gc "statepoint-example" {
  bb0:
    call void @__init.Test_cmp()
    ret void
  }
  
  define void @__init.Test_cmp() gc "statepoint-example" {
  bb0:
    %__sy_cir_init_tmp_0 = call i1 @__init_global.syliTest_cmp.eq()
    store i1 %__sy_cir_init_tmp_0, ptr @syliTest_cmp.eq
    %__sy_cir_init_tmp_1 = call i1 @__init_global.syliTest_cmp.lt()
    store i1 %__sy_cir_init_tmp_1, ptr @syliTest_cmp.lt
    ret void
  }
  
  define i1 @__init_global.syliTest_cmp.lt() gc "statepoint-example" {
  bb0:
    %Sy_cir_var_0 = call i1 @"syliTest_cmp.<"(i64 2, i64 5)
    ret i1 %Sy_cir_var_0
  }
  
  define i1 @__init_global.syliTest_cmp.eq() gc "statepoint-example" {
  bb0:
    %Sy_cir_var_0 = call i1 @"syliTest_cmp.=="(i64 5, i64 5)
    ret i1 %Sy_cir_var_0
  }
  
  define i1 @"syliTest_cmp.=="(i64 %x, i64 %y) gc "statepoint-example" {
  bb0:
    %Sy_prim_result = icmp eq i64 %x, %y
    ret i1 %Sy_prim_result
  }
  
  define i1 @"syliTest_cmp.<"(i64 %x, i64 %y) gc "statepoint-example" {
  bb0:
    %Sy_prim_result = icmp slt i64 %x, %y
    ret i1 %Sy_prim_result
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -4
    %r = inttoptr i64 %u to ptr addrspace(1)
    ret ptr addrspace(1) %r
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_borrow(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -2
    %r = inttoptr i64 %u to ptr addrspace(1)
    ret ptr addrspace(1) %r
  }
  
  define void @syli_inlinable_ownership_release(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 3
    %is_own = icmp eq i64 %tag, 1
    br i1 %is_own, label %own, label %done
  own:
    call void @syli_rt_ownership_decr(ptr addrspace(1) %p)
    ret void
  done:
    ret void
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_own(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 3
    %is_borrow = icmp eq i64 %tag, 0
    br i1 %is_borrow, label %promote, label %done
  promote:
    %r = or i64 %pi, 1
    %rp = inttoptr i64 %r to ptr addrspace(1)
    call void @syli_rt_ownership_incr(ptr addrspace(1) %rp)
    ret ptr addrspace(1) %rp
  done:
    ret ptr addrspace(1) %p
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_share(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 2
    %is_always = icmp ne i64 %tag, 0
    br i1 %is_always, label %done, label %promote
  promote:
    %r = or i64 %pi, 1
    %rp = inttoptr i64 %r to ptr addrspace(1)
    call void @syli_rt_ownership_incr(ptr addrspace(1) %rp)
    ret ptr addrspace(1) %rp
  done:
    ret ptr addrspace(1) %p
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_make_always_borrow(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -4
    %r = or i64 %u, 2
    %rp = inttoptr i64 %r to ptr addrspace(1)
    ret ptr addrspace(1) %rp
  }
  

Simple Function:
  $ cat >test_fn.sy <<EOF
  > primitive (+) : i64 -> i64 -> i64 = "add"
  > let add x y = x + 20 + y
  > EOF
  $ dune exec sylic -- llvm test_fn.sy
  declare void @syli_rt_ownership_decr(ptr addrspace(1))
  declare void @syli_rt_ownership_incr(ptr addrspace(1))
  
  define i32 @syli_startup_program() gc "statepoint-example" {
  bb0:
    call void @syli_modules_init()
    ret i32 0
  }
  
  define void @syli_modules_init() gc "statepoint-example" {
  bb0:
    call void @__init.Test_fn()
    ret void
  }
  
  define void @__init.Test_fn() gc "statepoint-example" {
  bb0:
    ret void
  }
  
  define i64 @syliTest_fn.add(i64 %x, i64 %y) gc "statepoint-example" {
  bb0:
    %Sy_cir_var_0 = call i64 @"syliTest_fn.+"(i64 %x, i64 20)
    %Sy_cir_var_1 = call i64 @"syliTest_fn.+"(i64 %Sy_cir_var_0, i64 %y)
    ret i64 %Sy_cir_var_1
  }
  
  define i64 @"syliTest_fn.+"(i64 %x, i64 %y) gc "statepoint-example" {
  bb0:
    %Sy_prim_result = add i64 %x, %y
    ret i64 %Sy_prim_result
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -4
    %r = inttoptr i64 %u to ptr addrspace(1)
    ret ptr addrspace(1) %r
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_borrow(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -2
    %r = inttoptr i64 %u to ptr addrspace(1)
    ret ptr addrspace(1) %r
  }
  
  define void @syli_inlinable_ownership_release(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 3
    %is_own = icmp eq i64 %tag, 1
    br i1 %is_own, label %own, label %done
  own:
    call void @syli_rt_ownership_decr(ptr addrspace(1) %p)
    ret void
  done:
    ret void
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_own(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 3
    %is_borrow = icmp eq i64 %tag, 0
    br i1 %is_borrow, label %promote, label %done
  promote:
    %r = or i64 %pi, 1
    %rp = inttoptr i64 %r to ptr addrspace(1)
    call void @syli_rt_ownership_incr(ptr addrspace(1) %rp)
    ret ptr addrspace(1) %rp
  done:
    ret ptr addrspace(1) %p
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_share(ptr addrspace(1) %p) {
  bb0:
    %pi = ptrtoint ptr addrspace(1) %p to i64
    %tag = and i64 %pi, 2
    %is_always = icmp ne i64 %tag, 0
    br i1 %is_always, label %done, label %promote
  promote:
    %r = or i64 %pi, 1
    %rp = inttoptr i64 %r to ptr addrspace(1)
    call void @syli_rt_ownership_incr(ptr addrspace(1) %rp)
    ret ptr addrspace(1) %rp
  done:
    ret ptr addrspace(1) %p
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_make_always_borrow(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -4
    %r = or i64 %u, 2
    %rp = inttoptr i64 %r to ptr addrspace(1)
    ret ptr addrspace(1) %rp
  }
  

Tuple emits syli_object_create and syli_object_set runtime calls:
  $ cat >test_tuple.sy <<EOF
  > let pair = (1, 2)
  > EOF
  $ dune exec sylic -- llvm test_tuple.sy
  Fatal error: exception Middle_end__Lower_core_to_cir.Lowering_error("core form not lowered to SIR yet")
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
