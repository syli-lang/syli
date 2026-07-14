SIR lowering tests — if-then-else expressions with multi-block SIR

If-then-else with i64 result:
  $ cat >test_if_i64.sy <<EOF
  > let x = if true then 1 else 0
  > EOF
  $ dune exec sylic -- cir test_if_i64.sy
  module Test_if_i64 :
  globals:
  global public syliTest_if_i64.x : i64 = null init=__init_global.syliTest_if_i64.x
  
  
  functions:
  public fn __init.Test_if_i64() -> void:
    entry: bb0
  
    bb0:
      %__init_tmp_0:i64 = #call_direct __init_global.syliTest_if_i64.x ()
      store_global syliTest_if_i64.x = %__init_tmp_0:i64
      return
  end
  
  private fn __init_global.syliTest_if_i64.x() -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:bool = cast(true:bool as bool)
      cond_br %Sy_var0:bool, bb1, bb2
  
    bb2:
      %Sy_var1:i64 = move(0:i64)
      goto bb3
  
    bb1:
      %Sy_var1:i64 = move(1:i64)
      goto bb3
  
    bb3:
  
      return %Sy_var1:i64
  end
  
  end

If-then-else with bool comparison:
  $ cat >test_if_cmp.sy <<EOF
  > let x = 10
  > let y = if x > 5 then 1 else 0
  > EOF
  $ dune exec sylic -- cir test_if_cmp.sy
  module Test_if_cmp :
  globals:
  global public syliTest_if_cmp.x : i64 = 10 init=__init_global.syliTest_if_cmp.x
  global public syliTest_if_cmp.y : i64 = null init=__init_global.syliTest_if_cmp.y
  
  
  functions:
  public fn __init.Test_if_cmp() -> void:
    entry: bb0
  
    bb0:
      %__init_tmp_0:i64 = #call_direct __init_global.syliTest_if_cmp.x ()
      store_global syliTest_if_cmp.x = %__init_tmp_0:i64
      %__init_tmp_1:i64 = #call_direct __init_global.syliTest_if_cmp.y ()
      store_global syliTest_if_cmp.y = %__init_tmp_1:i64
      return
  end
  
  private fn __init_global.syliTest_if_cmp.y() -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:bool = %syliTest_if_cmp.x:i64 > 5:i64
      cond_br %Sy_var0:bool, bb1, bb2
  
    bb2:
      %Sy_var1:i64 = move(0:i64)
      goto bb3
  
    bb1:
      %Sy_var1:i64 = move(1:i64)
      goto bb3
  
    bb3:
  
      return %Sy_var1:i64
  end
  
  private fn __init_global.syliTest_if_cmp.x() -> i64:
    entry: bb0
  
    bb0:
  
      return 10:i64
  end
  
  end

If-then-else without else (unit):
  $ cat >test_if_unit.sy <<EOF
  > let x = if true then () else ()
  > EOF
  $ dune exec sylic -- cir test_if_unit.sy
  module Test_if_unit :
  globals:
  global public syliTest_if_unit.x : void = null init=__init_global.syliTest_if_unit.x
  
  
  functions:
  public fn __init.Test_if_unit() -> void:
    entry: bb0
  
    bb0:
      %__init_tmp_0:void = #call_direct __init_global.syliTest_if_unit.x ()
      store_global syliTest_if_unit.x = %__init_tmp_0:void
      return
  end
  
  private fn __init_global.syliTest_if_unit.x() -> void:
    entry: bb0
  
    bb0:
      %Sy_var0:bool = cast(true:bool as bool)
      cond_br %Sy_var0:bool, bb1, bb2
  
    bb2:
      %Sy_var1:void = move(null:void)
      goto bb3
  
    bb1:
      %Sy_var1:void = move(null:void)
      goto bb3
  
    bb3:
  
      return %Sy_var1:void
  end
  
  end

Closure as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > let apply f x y = f x y
  > let add x y z = x
  > fn main () =
  >   let add1 = add 1
  >   let result =
  >     if true then
  >       apply add1 3 4
  >     else apply add1 1.0 2.0
  > EOF
  $ dune exec sylic -- cir test_multi.sy
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
      %Sy_var0:(?88, ?89 -> i64) = #make_closure {syliTest_multi.add} () ( captured_args=[1:i64])
      %Sy_var1:bool = cast(true:bool as bool)
      cond_br %Sy_var1:bool, bb1, bb2
  
    bb2:
      %Sy_var5:(f64, f64 -> i64) = cast(%Sy_var0:(?88, ?89 -> i64) as (f64, f64 -> i64))
      %Sy_var6:i64 = #call_direct syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64 (%Sy_var5:(f64, f64 -> i64), 1.0f:f64, 2.0f:f64)
      %Sy_var2:i64 = move(%Sy_var6:i64)
      goto bb3
  
    bb1:
      %Sy_var3:(i64, i64 -> i64) = cast(%Sy_var0:(?88, ?89 -> i64) as (i64, i64 -> i64))
      %Sy_var4:i64 = #call_direct syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64 (%Sy_var3:(i64, i64 -> i64), 3:i64, 4:i64)
      %Sy_var2:i64 = move(%Sy_var4:i64)
      goto bb3
  
    bb3:
  
      return %Sy_var2:i64
  end
  
  public fn syliTest_multi.apply__fn_i64_i64_i64__i64__i64_ret_i64(%f:(i64, i64 -> i64), %x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = #call_apply {%f:(i64, i64 -> i64)}  (%x:i64, %y:i64)
      return %Sy_var0:i64
  end
  
  public fn syliTest_multi.apply__fn_f64_f64_i64__f64__f64_ret_i64(%f:(f64, f64 -> i64), %x:f64, %y:f64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_var0:i64 = #call_apply {%f:(f64, f64 -> i64)}  (%x:f64, %y:f64)
      return %Sy_var0:i64
  end
  
  public fn syliTest_multi.add__i64__i64__i64_ret_i64(%x:i64, %y:i64, %z:i64) -> i64:
    entry: bb0
  
    bb0:
  
      return %x:i64
  end
  
  public fn syliTest_multi.add__i64__f64__f64_ret_i64(%x:i64, %y:f64, %z:f64) -> i64:
    entry: bb0
  
    bb0:
  
      return %x:i64
  end
  
  end

Closure as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > let apply f x y = f x y
  > let add x y z = x
  > fn main () =
  >   let add1 = add 1
  >   let result =
  >     if true then
  >       let m = 4
  >       apply add1 3 m
  >     else
  >       let m = 2.0
  >       apply add1 1.0 m
  > EOF
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  let syliTest_multi.apply = fun (f, x, y) : 'a89 ->
      f(x : 'a83, y : 'a85) : 'a89
  
  let syliTest_multi.add = fun (x, y, z) : 'a91 ->
      x : 'a91
  
  let syliTest_multi.main = fun () : i64 ->
      {
        let syliTest_multi.main__add1 = syliTest_multi.add(1 : i64) : ('a100, 'a101) -> i64
        let syliTest_multi.main__result = if true : bool
            {
              let syliTest_multi.main__result__m = 4 : i64
              syliTest_multi.apply(syliTest_multi.main__add1 : (i64, i64) -> i64, 3 : i64, syliTest_multi.main__result__m : i64) : i64
            }
          else
            {
              let syliTest_multi.main__result__m#1 = 2.0 : double
              syliTest_multi.apply(syliTest_multi.main__add1 : (double, double) -> i64, 1.0 : double, syliTest_multi.main__result__m#1 : double) : i64
            }
      }
  
Closure as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > let apply f x y = f x y
  > let add x y z = x
  > fn main () =
  >   let add1 = add 1
  >   let add2 =
  >     if true then
  >       let x = add1 4
  >       x
  >     else
  >       let x = add1 2.0
  >       x
  >   let result2 = add2 4 
  >   result2
  > EOF
  $ dune exec sylic -- core test_multi.sy
  module Test_multi
  let syliTest_multi.apply = fun (f, x, y) : 'a91 ->
      f(x : 'a85, y : 'a87) : 'a91
  
  let syliTest_multi.add = fun (x, y, z) : 'a93 ->
      x : 'a93
  
  let syliTest_multi.main = fun () : i64 ->
      {
        let syliTest_multi.main__add1 = syliTest_multi.add(1 : i64) : ('a102, 'a103) -> i64
        let syliTest_multi.main__add2 = if true : bool
            {
              let syliTest_multi.main__add2__x = syliTest_multi.main__add1(4 : i64) : ('a106) -> i64
              syliTest_multi.main__add2__x : ('a112) -> i64
            }
          else
            {
              let syliTest_multi.main__add2__x#1 = syliTest_multi.main__add1(2.0 : double) : ('a110) -> i64
              syliTest_multi.main__add2__x#1 : ('a112) -> i64
            }
        let syliTest_multi.main__result2 = syliTest_multi.main__add2(4 : i64) : i64
        syliTest_multi.main__result2 : i64
      }
  

Closure as an argument with multiple captured variables:
  $ cat >test_multi.sy <<EOF
  > let apply f x y = f x y
  > let add x y z = x
  > fn main () =
  >   let add1 = add 1
  >   let add2 =
  >     if true then
  >       let x = add1 4
  >       x
  >     else
  >       let x = add1 2.0
  >       x
  >   let result2 = add2 4 
  >   result2
  > EOF
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
      %Sy_var0:(?102, ?103 -> i64) = #make_closure {syliTest_multi.add} () ( captured_args=[1:i64])
      %Sy_var1:bool = cast(true:bool as bool)
      cond_br %Sy_var1:bool, bb1, bb2
  
    bb1:
      %Sy_var3:(?106 -> i64) = #partial_apply {%Sy_var0:(?102, ?103 -> i64)} (4:i64)
      %Sy_var2:(?112 -> i64) = move(%Sy_var3:(?106 -> i64))
      goto bb3
  
    bb2:
      %Sy_var4:(?110 -> i64) = #partial_apply {%Sy_var0:(?102, ?103 -> i64)} (2.0f:f64)
      %Sy_var2:(?112 -> i64) = move(%Sy_var4:(?110 -> i64))
      goto bb3
  
    bb3:
      %Sy_var5:i64 = #call_apply {%Sy_var2:(?112 -> i64) as (i64 -> i64)}  (4:i64)
      return %Sy_var5:i64
  end
  
  public fn syliTest_multi.add(%x:?93, %y:?95, %z:?97) -> ?93:
    entry: bb0
  
    bb0:
  
      return %x:?93
  end
  
  public fn syliTest_multi.apply(%f:(?85, ?87 -> ?91), %x:?85, %y:?87) -> ?91:
    entry: bb0
  
    bb0:
      %Sy_var0:?91 = #call_apply {%f:(?85, ?87 -> ?91)}  (%x:?85, %y:?87)
      return %Sy_var0:?91
  end
  
  end
