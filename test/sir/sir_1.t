SIR lowering tests — Syli source to Syli SIR

Integer literal:
  $ cat >test_int.sy <<EOF
  > let x = 42
  > EOF
  $ dune exec sylic -- cir test_int.sy
  module Test_int :
  globals:
  global public syliTest_int.x : i64 = 42 init=__init_global.syliTest_int.x
  
  
  functions:
  public fn __init.Test_int() -> void:
    entry: bb0
  
    bb0:
      %__sy_cir_init_tmp_0:i64 = #call_direct __init_global.syliTest_int.x ()
      store_global syliTest_int.x = %__sy_cir_init_tmp_0:i64
      return
  end
  
  private fn __init_global.syliTest_int.x() -> i64:
    entry: bb0
  
    bb0:
  
      return 42:i64
  end
  
  end


Boolean literals:
  $ cat >test_bool.sy <<EOF
  > let p = true
  > let q = false
  > EOF
  $ dune exec sylic -- cir test_bool.sy
  module Test_bool :
  globals:
  global public syliTest_bool.p : bool = true init=__init_global.syliTest_bool.p
  global public syliTest_bool.q : bool = false init=__init_global.syliTest_bool.q
  
  
  functions:
  public fn __init.Test_bool() -> void:
    entry: bb0
  
    bb0:
      %__sy_cir_init_tmp_0:bool = #call_direct __init_global.syliTest_bool.p ()
      store_global syliTest_bool.p = %__sy_cir_init_tmp_0:bool
      %__sy_cir_init_tmp_1:bool = #call_direct __init_global.syliTest_bool.q ()
      store_global syliTest_bool.q = %__sy_cir_init_tmp_1:bool
      return
  end
  
  private fn __init_global.syliTest_bool.q() -> bool:
    entry: bb0
  
    bb0:
  
      return false:bool
  end
  
  private fn __init_global.syliTest_bool.p() -> bool:
    entry: bb0
  
    bb0:
  
      return true:bool
  end
  
  end


String literal:
  $ cat >test_str.sy <<EOF
  > let s = "hello"
  > EOF
  $ dune exec sylic -- cir test_str.sy
  module Test_str :
  globals:
  global public syliTest_str.s : string = "hello" init=__init_global.syliTest_str.s
  
  
  functions:
  public fn __init.Test_str() -> void:
    entry: bb0
  
    bb0:
      %__sy_cir_init_tmp_0:string = #call_direct __init_global.syliTest_str.s ()
      store_global syliTest_str.s = %__sy_cir_init_tmp_0:string
      return
  end
  
  private fn __init_global.syliTest_str.s() -> string:
    entry: bb0
  
    bb0:
  
      return hello:string
  end
  
  end

Empty string literal:
  $ cat >test_empty.sy <<EOF
  > let s = ""
  > EOF
  $ dune exec sylic -- cir test_empty.sy
  module Test_empty :
  globals:
  global public syliTest_empty.s : string = "" init=__init_global.syliTest_empty.s
  
  
  functions:
  public fn __init.Test_empty() -> void:
    entry: bb0
  
    bb0:
      %__sy_cir_init_tmp_0:string = #call_direct __init_global.syliTest_empty.s ()
      store_global syliTest_empty.s = %__sy_cir_init_tmp_0:string
      return
  end
  
  private fn __init_global.syliTest_empty.s() -> string:
    entry: bb0
  
    bb0:
  
      return :string
  end
  
  end

Arithmetic operations:
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
  $ dune exec sylic -- cir test_arith.sy
  module Test_arith :
  globals:
  global public syliTest_arith.a : i64 = null init=__init_global.syliTest_arith.a
  global public syliTest_arith.b : i64 = null init=__init_global.syliTest_arith.b
  global public syliTest_arith.c : i64 = null init=__init_global.syliTest_arith.c
  global public syliTest_arith.d : i64 = null init=__init_global.syliTest_arith.d
  
  
  functions:
  public fn __init.Test_arith() -> void:
    entry: bb0
  
    bb0:
      %__sy_cir_init_tmp_0:i64 = #call_direct __init_global.syliTest_arith.a ()
      store_global syliTest_arith.a = %__sy_cir_init_tmp_0:i64
      %__sy_cir_init_tmp_1:i64 = #call_direct __init_global.syliTest_arith.b ()
      store_global syliTest_arith.b = %__sy_cir_init_tmp_1:i64
      %__sy_cir_init_tmp_2:i64 = #call_direct __init_global.syliTest_arith.c ()
      store_global syliTest_arith.c = %__sy_cir_init_tmp_2:i64
      %__sy_cir_init_tmp_3:i64 = #call_direct __init_global.syliTest_arith.d ()
      store_global syliTest_arith.d = %__sy_cir_init_tmp_3:i64
      return
  end
  
  private fn __init_global.syliTest_arith.d() -> i64:
    entry: bb0
  
    bb0:
      %Sy_cir_var_0:i64 = #call_direct "syliTest_arith./" (20:i64, 4:i64)
      return %Sy_cir_var_0:i64
  end
  
  private fn __init_global.syliTest_arith.c() -> i64:
    entry: bb0
  
    bb0:
      %Sy_cir_var_0:i64 = #call_direct "syliTest_arith.*" (4:i64, 6:i64)
      return %Sy_cir_var_0:i64
  end
  
  private fn __init_global.syliTest_arith.b() -> i64:
    entry: bb0
  
    bb0:
      %Sy_cir_var_0:i64 = #call_direct "syliTest_arith.-" (10:i64, 2:i64)
      return %Sy_cir_var_0:i64
  end
  
  private fn __init_global.syliTest_arith.a() -> i64:
    entry: bb0
  
    bb0:
      %Sy_cir_var_0:i64 = #call_direct "syliTest_arith.+" (5:i64, 3:i64)
      return %Sy_cir_var_0:i64
  end
  
  public fn "syliTest_arith.+"(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_prim_result:i64 = %x:i64 + %y:i64
      return %Sy_prim_result:i64
  end
  
  public fn "syliTest_arith.*"(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_prim_result:i64 = %x:i64 * %y:i64
      return %Sy_prim_result:i64
  end
  
  public fn "syliTest_arith.-"(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_prim_result:i64 = %x:i64 - %y:i64
      return %Sy_prim_result:i64
  end
  
  public fn "syliTest_arith./"(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_prim_result:i64 = %x:i64 / %y:i64
      return %Sy_prim_result:i64
  end
  
  end

Comparison operations produce a temporary variable:
  $ cat >test_cmp.sy <<EOF
  > primitive (==) : i64 -> i64 -> bool = "eq"
  > primitive (<) : i64 -> i64 -> bool = "lt"
  > let eq = 5 == 5
  > let lt = 2 < 5
  > EOF
  $ dune exec sylic -- cir test_cmp.sy
  module Test_cmp :
  globals:
  global public syliTest_cmp.eq : bool = null init=__init_global.syliTest_cmp.eq
  global public syliTest_cmp.lt : bool = null init=__init_global.syliTest_cmp.lt
  
  
  functions:
  public fn __init.Test_cmp() -> void:
    entry: bb0
  
    bb0:
      %__sy_cir_init_tmp_0:bool = #call_direct __init_global.syliTest_cmp.eq ()
      store_global syliTest_cmp.eq = %__sy_cir_init_tmp_0:bool
      %__sy_cir_init_tmp_1:bool = #call_direct __init_global.syliTest_cmp.lt ()
      store_global syliTest_cmp.lt = %__sy_cir_init_tmp_1:bool
      return
  end
  
  private fn __init_global.syliTest_cmp.lt() -> bool:
    entry: bb0
  
    bb0:
      %Sy_cir_var_0:bool = #call_direct "syliTest_cmp.<" (2:i64, 5:i64)
      return %Sy_cir_var_0:bool
  end
  
  private fn __init_global.syliTest_cmp.eq() -> bool:
    entry: bb0
  
    bb0:
      %Sy_cir_var_0:bool = #call_direct "syliTest_cmp.==" (5:i64, 5:i64)
      return %Sy_cir_var_0:bool
  end
  
  public fn "syliTest_cmp.=="(%x:i64, %y:i64) -> bool:
    entry: bb0
  
    bb0:
      %Sy_prim_result:bool = %x:i64 == %y:i64
      return %Sy_prim_result:bool
  end
  
  public fn "syliTest_cmp.<"(%x:i64, %y:i64) -> bool:
    entry: bb0
  
    bb0:
      %Sy_prim_result:bool = %x:i64 < %y:i64
      return %Sy_prim_result:bool
  end
  
  end


Tuple creates an object with two fields:
  $ cat >test_tuple.sy <<EOF
  > let pair = (1, 2)
  > EOF
  $ dune exec sylic -- cir test_tuple.sy
  Fatal error: exception Middle_end__Lower_core_to_cir.Lowering_error("core form not lowered to SIR yet")
  [2]

Triple tuple creates an object with three fields:
  $ cat >test_triple.sy <<EOF
  > let triple = (true, 42, "x")
  > EOF
  $ dune exec sylic -- cir test_triple.sy
  Fatal error: exception Middle_end__Lower_core_to_cir.Lowering_error("core form not lowered to SIR yet")
  [2]

Type error propagates from typing phase:
  $ cat >test_tyerr.sy <<EOF
  > let x = 1 + true
  > EOF
  $ dune exec sylic -- cir test_tyerr.sy 2>&1
  Type error in test_tyerr.sy at line 1, column 8
  
    1 | let x = 1 + true
                ^^^^^^^^
  
  Unbound identifier '+'
  [1]

Collection literals are no longer supported (moved to traits):
  $ cat >test_arr.sy <<EOF
  > let arr = [1, 2, 3]
  > EOF
  $ dune exec sylic -- cir test_arr.sy 2>&1
  Parse error in test_arr.sy at line 1, column 10
  
    1 | let arr = [1, 2, 3]
                  ^
  
  Unexpected token: '['
  [1]

Missing file produces an error:
  $ cat >test_arr.sy <<EOF
  > let arr = [1, 2, 3]
  > EOF
  $ dune exec sylic -- cir test_arr.sy 2>&1
  Parse error in test_arr.sy at line 1, column 10
  
    1 | let arr = [1, 2, 3]
                  ^
  
  Unexpected token: '['
  [1]

Closures as an argument:
  $ cat >test_closure.src <<EOF
  > primitive (+) : i64 -> i64 -> i64 = "add"
  > let f y x = x + y
  > let apply_twice f x = f (f x)
  > let double_x x = x + x
  > let fx = f 2
  > let result = apply_twice double_x 10
  > EOF
  $ dune exec sylic -- typing test_closure.src
  Typed test_closure.src successfully: module Test_closure with 6 top-level typed items
  Type Environment:
  {
    + : i64 -> i64 -> i64
    apply_twice : forall '82. '82 -> '82 -> '82 -> '82
    double_x : i64 -> i64
    f : i64 -> i64 -> i64
    fx : i64 -> i64
    result : i64
  }

Closures as an argument:
  $ cat >test_closure.src <<EOF
  > primitive (+) : i64 -> i64 -> i64 = "add"
  > let apply_twice f x = f (f x)
  > let double_x x = x + x
  > let result = apply_twice double_x 10
  > EOF

  $ dune exec sylic -- cir test_closure.src
  module Test_closure :
  globals:
  global public syliTest_closure.result : i64 = null init=__init_global.syliTest_closure.result
  
  
  functions:
  public fn __init.Test_closure() -> void:
    entry: bb0
  
    bb0:
      %__sy_cir_init_tmp_0:i64 = #call_direct __init_global.syliTest_closure.result ()
      store_global syliTest_closure.result = %__sy_cir_init_tmp_0:i64
      return
  end
  
  private fn __init_global.syliTest_closure.result() -> i64:
    entry: bb0
  
    bb0:
      %Sy_cir_var_0:(i64 -> i64) = #make_closure {syliTest_closure.double_x} () ()
      %Sy_cir_var_1:i64 = #call_direct syliTest_closure.apply_twice__fn_i64_i64__i64_ret_i64 (%Sy_cir_var_0:(i64 -> i64), 10:i64)
      return %Sy_cir_var_1:i64
  end
  
  public fn syliTest_closure.double_x(%x:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_cir_var_0:i64 = #call_direct "syliTest_closure.+" (%x:i64, %x:i64)
      return %Sy_cir_var_0:i64
  end
  
  public fn "syliTest_closure.+"(%x:i64, %y:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_prim_result:i64 = %x:i64 + %y:i64
      return %Sy_prim_result:i64
  end
  
  public fn syliTest_closure.apply_twice__fn_i64_i64__i64_ret_i64(%f:(i64 -> i64), %x:i64) -> i64:
    entry: bb0
  
    bb0:
      %Sy_cir_var_0:i64 = #call_apply {%f:(i64 -> i64)}  (%x:i64)
      %Sy_cir_var_1:i64 = #call_apply {%f:(i64 -> i64)}  (%Sy_cir_var_0:i64)
      return %Sy_cir_var_1:i64
  end
  
  end


Char literal:
  $ cat >test_char.sy <<EOF
  > let c = 'A'
  > EOF
  $ dune exec sylic -- cir test_char.sy
  module Test_char :
  globals:
  global public syliTest_char.c : char = 'A' init=__init_global.syliTest_char.c
  
  
  functions:
  public fn __init.Test_char() -> void:
    entry: bb0
  
    bb0:
      %__sy_cir_init_tmp_0:char = #call_direct __init_global.syliTest_char.c ()
      store_global syliTest_char.c = %__sy_cir_init_tmp_0:char
      return
  end
  
  private fn __init_global.syliTest_char.c() -> char:
    entry: bb0
  
    bb0:
  
      return 'A':char
  end
  
  end
