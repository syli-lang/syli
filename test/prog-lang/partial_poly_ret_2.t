  $ cat >test_multi.sy <<EOF
  > let add x y z = z
  > fn main () =
  >   let add1 = add 1
  >   let a0 = add1 1.0
  >   let b0 = add1 1
  >   let a1 = a0 1

  $ dune exec sylic -- cir_raw test_multi.sy
  module Test_multi :
  functions:
  public fn __init.Test_multi() -> void:
    entry: bb0
  
    bb0:
  
      return
  end
  
  public fn syliTest_multi.main() -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:(?61, ?62 -> ?62) = #make_closure {syliTest_multi.add} () ( captured_args=[1:i64])
      %Sy_var1:(?65 -> ?65) = #partial_apply {%Sy_var0:(?61, ?62 -> ?62)} (1.0f:f64)
      %Sy_var2:(?68 -> ?68) = #partial_apply {%Sy_var0:(?61, ?62 -> ?62)} (1:i64)
      %Sy_var3:i64 = #call_apply {%Sy_var1:(?65 -> ?65) as (i64 -> i64)}  (1:i64)
      return %Sy_var3:i64
  end
  
  public fn syliTest_multi.add(%x:?52, %y:?54, %z:?56) -> ?56:
    entry: bb0
  
    bb0:
  
      return %z:?56
  end
  
  end

  $ dune exec sylic -- typing test_multi.sy
  Typed test_multi.sy successfully: module Test_multi with 2 top-level typed items
  Type Environment:
  {
    add : forall '52 '54 '56. ('52, '54, '56) -> '56
    main : (unit) -> int64
  }

  $ dune exec sylic -- oir test_multi.sy
  Fatal error: exception Failure("Cir.CR_GenericTyp should be monomorphized before lowering to OIR")
  ***** UNREACHABLE *****

