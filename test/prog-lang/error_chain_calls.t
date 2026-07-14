Monomorphization issue.
  $ cat >test_file.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  > end
  > let add x y z = y + z
  > let apply () =
  >   let add1 = add 1
  >   let add1and2 = add1 2
  >   let result = add1and2 3
  > fn main () = 
  >   let result = apply ()
  >   syli_print_i64 result
  > EOF

  $ dune exec sylic -- core test_file.sy > test_file.core
  $ dune exec sylic -- cir_raw test_file.sy
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
      %Sy_var0:i64 = #call_direct syliTest_file.apply ()
      %Sy_var1:void = #call_direct syliTest_file.syli_print_i64 (%Sy_var0:i64)
      return
  end
  
  public fn syliTest_file.apply() -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:(?81, ?81 -> ?81) = #make_closure {syliTest_file.add} () ( captured_args=[1:i64])
      %Sy_var1:(i64 -> i64) = #partial_apply {%Sy_var0:(?81, ?81 -> ?81)} (2:i64)
      %Sy_var2:i64 = #call_apply {%Sy_var1:(i64 -> i64)}  (3:i64)
      return %Sy_var2:i64
  end
  
  public fn syliTest_file.add(%x:?72, %y:?76, %z:?76) -> ?76:
    entry: bb0
  
    bb0:
      %Sy_var0:?76 = %y:?76 + %z:?76
      return %Sy_var0:?76
  end
  
  end

  $ dune exec sylic -- cir test_file.sy > test_file.ir
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
      %Sy_var0:i64 = #call_direct syliTest_file.apply ()
      %Sy_var1:void = #call_direct syliTest_file.syli_print_i64 (%Sy_var0:i64)
      return
  end
  
  public fn syliTest_file.apply() -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:(?81, ?81 -> ?81) = #make_closure {syliTest_file.add} () ( captured_args=[1:i64])
      %Sy_var1:(i64 -> i64) = #partial_apply {%Sy_var0:(?81, ?81 -> ?81)} (2:i64)
      %Sy_var2:i64 = #call_apply {%Sy_var1:(i64 -> i64)}  (3:i64)
      return %Sy_var2:i64
  end
  
  public fn syliTest_file.add__i64__i64__i64_ret_i64(%x:i64, %y:i64, %z:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %y:i64 + %z:i64
      return %Sy_var0:i64
  end
  
  end
