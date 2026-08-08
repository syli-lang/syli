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
  declare void @syli_rt_ownership_decr(ptr addrspace(1))
  declare void @syli_rt_ownership_incr(ptr addrspace(1))
  
  define i32 @syli_startup_program(i32 %argc, ptr %argv) gc "statepoint-example" {
  bb0:
    call void @syli_modules_init()
    call void @syliTest_binary.main()
    ret i32 0
  }
  
  define void @syli_modules_init() gc "statepoint-example" {
  bb0:
    call void @__init.Test_binary()
    ret void
  }
  
  define void @__init.Test_binary() gc "statepoint-example" {
  bb0:
    ret void
  }
  
  define void @syliTest_binary.main() gc "statepoint-example" {
  bb0:
    call void @syli_print_i64(i64 42)
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
  
