open Types

let ty_of_operand = function
  | LV_Constant (_, ty) -> ty
  | LV_Local (_, ty) -> ty
  | LV_Global (_, ty) -> ty

let i64 n = LV_Constant (LV_Integer (Int64.of_int n), LV_I64)
let i32 n = LV_Constant (LV_Integer (Int64.of_int n), LV_I32)
let i16 n = LV_Constant (LV_Integer (Int64.of_int n), LV_I16)
let i8 n = LV_Constant (LV_Integer (Int64.of_int n), LV_I8)
let i1 b = LV_Constant (LV_Integer (if b then 1L else 0L), LV_I1)
let f32 f = LV_Constant (LV_Float f, LV_Float)
let f64 f = LV_Constant (LV_Double f, LV_Double)
let null ty = LV_Constant (LV_Null, ty)
let zeroinitializer ty = LV_Constant (LV_ZeroInitializer, ty)
let local name ty = LV_Local (name, ty)
let global name ty = LV_Global (name, ty)

let rec string_of_lltype = function
  | LV_I1 -> "i1"
  | LV_I8 -> "i8"
  | LV_I16 -> "i16"
  | LV_I32 -> "i32"
  | LV_I64 -> "i64"
  | LV_Float -> "float"
  | LV_Double -> "double"
  | LV_Void -> "void"
  | LV_Ptr -> "ptr"
  | LV_Array (len, ty) -> Printf.sprintf "[%d x %s]" len (string_of_lltype ty)
  | LV_Struct fields ->
      let fields_str = String.concat ", " (List.map string_of_lltype fields) in
      "{ " ^ fields_str ^ " }"
  | LV_Named name -> "%" ^ name
  | LV_Func (args, ret) ->
      let args_str = String.concat ", " (List.map string_of_lltype args) in
      Printf.sprintf "%s (%s)" (string_of_lltype ret) args_str

let string_of_float_literal f =
  let s = string_of_float f in
  if String.contains s '.' then s else s ^ ".0"

let string_of_operand = function
  | LV_Constant (LV_Integer n, LV_I1) -> if n = 0L then "false" else "true"
  | LV_Constant (LV_Integer n, _) -> Int64.to_string n
  | LV_Constant (LV_Float f, _) -> string_of_float_literal f
  | LV_Constant (LV_Double f, _) -> string_of_float_literal f
  | LV_Constant (LV_Null, _) -> "null"
  | LV_Constant (LV_ZeroInitializer, _) -> "zeroinitializer"
  | LV_Constant (LV_Array _, _) -> "<array_const>"
  | LV_Local (n, _) -> "%" ^ n
  | LV_Global (n, _) -> "@" ^ n

let string_of_typed_operand op =
  Printf.sprintf "%s %s"
    (string_of_lltype (ty_of_operand op))
    (string_of_operand op)

let string_of_ibinop = function
  | LV_IAdd -> "add"
  | LV_ISub -> "sub"
  | LV_IMul -> "mul"
  | LV_ISDiv -> "sdiv"
  | LV_IUDiv -> "udiv"
  | LV_ISRem -> "srem"
  | LV_IURem -> "urem"
  | LV_IBitAnd -> "and"
  | LV_IBitOr -> "or"
  | LV_IBitXor -> "xor"
  | LV_IShl -> "shl"
  | LV_ILShr -> "lshr"
  | LV_IAShr -> "ashr"

let string_of_fbinop = function
  | LV_FAdd -> "fadd"
  | LV_FSub -> "fsub"
  | LV_FMul -> "fmul"
  | LV_FDiv -> "fdiv"
  | LV_FRem -> "frem"

let string_of_icmp = function
  | LV_IEq -> "eq"
  | LV_INe -> "ne"
  | LV_ISlt -> "slt"
  | LV_ISle -> "sle"
  | LV_ISgt -> "sgt"
  | LV_ISge -> "sge"
  | LV_IUlt -> "ult"
  | LV_IUle -> "ule"
  | LV_IUgt -> "ugt"
  | LV_IUge -> "uge"

let string_of_fcmp = function
  | LV_FOeq -> "oeq"
  | LV_FOgt -> "ogt"
  | LV_FOge -> "oge"
  | LV_FOlt -> "olt"
  | LV_FOle -> "ole"
  | LV_FOne -> "one"
  | LV_FOrd -> "ord"

let string_of_cast_op = function
  | LV_ZExt -> "zext"
  | LV_SExt -> "sext"
  | LV_Trunc -> "trunc"
  | LV_FPExt -> "fpext"
  | LV_FPTrunc -> "fptrunc"
  | LV_FPToSI -> "fptosi"
  | LV_FPToUI -> "fptoui"
  | LV_SIToFP -> "sitofp"
  | LV_UIToFP -> "uitofp"
  | LV_PtrToInt -> "ptrtoint"
  | LV_IntToPtr -> "inttoptr"
  | LV_BitCast -> "bitcast"

let string_of_terminator = function
  | LV_Ret None -> "ret void"
  | LV_Ret (Some op) -> Printf.sprintf "ret %s" (string_of_typed_operand op)
  | LV_Br label -> Printf.sprintf "br label %%%s" label
  | LV_CondBr (cond, t, f) ->
      Printf.sprintf "br i1 %s, label %%%s, label %%%s" (string_of_operand cond)
        t f
  | LV_Switch (val_, default, cases) ->
      let buf = Buffer.create 64 in
      Printf.bprintf buf "switch %s, label %%%s ["
        (string_of_typed_operand val_)
        default;
      List.iter
        (fun (v, l) ->
          Printf.bprintf buf "\n    %s, label %%%s"
            (string_of_typed_operand v)
            l)
        cases;
      Printf.bprintf buf "\n  ]";
      Buffer.contents buf
  | LV_Unreachable -> "unreachable"
