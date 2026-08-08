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
      %Sy_var0:person{{card=2 [0:i64; 1:i64]} tag=- unknown_cyclic} = object_create{size=2:i64}
      obj_set(%Sy_var0:obj_ptr, 0:i64, 10:i64):i64
      obj_set(%Sy_var0:obj_ptr, 1:i64, 30:i64):i64
      %Sy_var1:i64 = obj_get(%Sy_var0:obj_ptr, 1:i64):i64
      %Sy_var2:void = #call_direct syliTest_e2e_print.syli_print_i64 (%Sy_var1:i64)
      return
  end
  
  end
  $ dune exec sylic -- llvm test_e2e_print.sy > test_e2e_print.ll
  $ cat test_e2e_print.ll
  declare void @syli_print_i64(i64)
  declare void @syli_rt_gc_cycle()
  declare ptr addrspace(1) @syli_rt_ownership_alloc_object(i64, i32, i64)
  declare void @syli_rt_ownership_decr(ptr addrspace(1))
  declare void @syli_rt_ownership_incr(ptr addrspace(1))
  
  define i32 @syli_startup_program(i32 %argc, ptr %argv) gc "statepoint-example" {
  bb0:
    call void @syli_modules_init()
    call void @syliTest_e2e_print.main()
    ret i32 0
  }
  
  define void @syli_modules_init() gc "statepoint-example" {
  bb0:
    call void @__init.Test_e2e_print()
    ret void
  }
  
  define void @__init.Test_e2e_print() gc "statepoint-example" {
  bb0:
    ret void
  }
  
  define void @syliTest_e2e_print.main() gc "statepoint-example" {
  bb0:
    call void @syli_rt_gc_cycle()
    %Sy_var0 = call ptr addrspace(1) @syli_rt_ownership_alloc_object(i64 2377900603251621890, i32 1, i64 2)
    ; nop
    %Sy_tmp0 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var0)
    %Sy_tmp1 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp0, i32 0, i32 2, i64 0
    store i64 10, ptr addrspace(1) %Sy_tmp1
    %Sy_tmp2 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var0)
    %Sy_tmp3 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp2, i32 0, i32 2, i64 1
    store i64 30, ptr addrspace(1) %Sy_tmp3
    %Sy_tmp4 = call ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %Sy_var0)
    %Sy_tmp5 = getelementptr { i64, i64, [0 x i64] }, ptr addrspace(1) %Sy_tmp4, i32 0, i32 2, i64 1
    %Sy_var1 = load i64, ptr addrspace(1) %Sy_tmp5
    call void @syli_inlinable_ownership_release(ptr addrspace(1) %Sy_var0)
    call void @syli_print_i64(i64 %Sy_var1)
    ret void
  }
  
  define ptr addrspace(1) @syli_inlinable_ownership_untag(ptr addrspace(1) %p) {
  bb0:
    %i = ptrtoint ptr addrspace(1) %p to i64
    %u = and i64 %i, -2
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
    %tag = and i64 %pi, 1
    %is_own = icmp ne i64 %tag, 0
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
    %tag = and i64 %pi, 1
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
  


  $ clang -c test_e2e_print.ll -o /dev/null 2>/dev/null
