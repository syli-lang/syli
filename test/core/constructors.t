constructor with a record argument
  $ cat >test_constr_record.sy <<'EOF'
  > type radius = { radius: i64 }
  > type shape = Circle of radius | Rect of { w: f64; h: f64 }
  > let c = Circle { radius = 1 }
  > let r =
  >   match c with 
  >   | Circle x -> x
  >   | Circle x -> x
  > EOF
  $ dune exec sylic core test_constr_record.sy
  module Test_constr_record
  type syliTest_constr_record.radius = { 0 : i64 }
  
  type syliTest_constr_record.shape = ctor18 of syliTest_constr_record.radius | ctor16 of { 0 : f64; 1 : f64 }
  
  let syliTest_constr_record.c = ctor(0, { 0 = 1 : i64 } : syliTest_constr_record.radius) : syliTest_constr_record.shape
  
  let syliTest_constr_record.r = match syliTest_constr_record.c : syliTest_constr_record.shape {
      |     ctor(0, sy1_x) -> sy1_x : syliTest_constr_record.radius
      |     ctor(0, sy2_x) -> sy2_x : syliTest_constr_record.radius
    }
  
