open Cir

type builtin_cast_rvalue =
  (* I64 *)
  | I64_to_i32
  | I64_to_i16
  | I64_to_i8
  | I64_to_ptr
  | I64_to_string
  | I64_to_double
  (* I32 *)
  | I32_to_i64
  | I32_to_i16
  | I32_to_float
  | I32_to_double
  (* I16 *)
  | I16_to_i64
  | I16_to_i32
  | I16_to_i8
  (* I8 *)
  | I8_to_i64
  | I8_to_i16
  (* U64 *)
  | U64_to_u32
  | U64_to_u16
  | U64_to_u8
  | U64_to_ptr
  | U64_to_string
  | U64_to_double
  (* U32 *)
  | U32_to_u64
  | U32_to_u16
  | U32_to_float
  | U32_to_double
  (* U16 *)
  | U16_to_u64
  | U16_to_u32
  | U16_to_u8
  (* U8 *)
  | U8_to_u64
  | U8_to_u16
  (* Bool *)
  | Bool_to_string
  (* Float *)
  | Float_to_i64
  | Float_to_i32
  | Float_to_string
  (* Ptr *)
  | Ptr_to_i64
  | Ptr_to_string
  (* String *)
  | String_to_i64
  | String_to_float
  (* Double *)
  | Double_to_i64
  | Double_to_i32
  | Double_to_string
