Closure with free variables:
  $ cat >test_multi.sy <<EOF
  > let apply () =
  >   let free = 1
  >   let add x y = free + y
  >   let result = add 1 2
  >   result
  > EOF
  $ dune exec sylic -- cir_raw test_multi.sy
  module Test_multi :
  functions:
  public fn __init.Test_multi() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_multi.apply() -> i64:
    entry: bb0
  
    bb0:
      %syliTest_multi.apply__free:i64 = cast(1:i64 as i64)
      %syliTest_multi.apply__add:(?41, i64 -> i64) = #make_closure {syliTest_multi.apply__add} (%syliTest_multi.apply__free:i64) ()
      %Sy_var0:i64 = #call_apply {%syliTest_multi.apply__add:(?41, i64 -> i64) as (i64, i64 -> i64)}  (1:i64, 2:i64)
      return %Sy_var0:i64
  end
  
  private fn syliTest_multi.apply__add(%syliTest_multi.apply__free:i64, %x:?41, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = %syliTest_multi.apply__free:i64 + %y:i64
      return %Sy_var0:i64
  end
  
  end

