(** This module defines the LLVM LIR (Low-Level Intermediate Representation)
    types used for generating LLVM IR output. *)

(** LLVM IR type kinds. *)
type lltype =
  | LV_I1
  | LV_I8
  | LV_I16
  | LV_I32
  | LV_I64
  | LV_Float
  | LV_Double
  | LV_Void
  | LV_Ptr
  | LV_Array of int * lltype
  | LV_Struct of lltype list
  | LV_Named of string
  | LV_Func of lltype list * lltype

(** LLVM IR constants. *)
type constant =
  | LV_Integer of int64
  | LV_Float of float
  | LV_Double of float
  | LV_Null
  | LV_ZeroInitializer
  | LV_Array of constant list

type const = constant
(** Alias for [constant]. *)

(** An operand in an LLVM instruction (constant, local, or global). *)
type operand =
  | LV_Constant of constant * lltype
  | LV_Local of string * lltype
  | LV_Global of string * lltype

(** Integer binary operators. *)
type ibinop =
  | LV_IAdd
  | LV_ISub
  | LV_IMul
  | LV_ISDiv
  | LV_IUDiv
  | LV_ISRem
  | LV_IURem
  | LV_IBitAnd
  | LV_IBitOr
  | LV_IBitXor
  | LV_IShl
  | LV_ILShr
  | LV_IAShr

(** Floating-point binary operators. *)
type fbinop = LV_FAdd | LV_FSub | LV_FMul | LV_FDiv | LV_FRem

(** Integer comparison conditions. *)
type icmp_cond =
  | LV_IEq
  | LV_INe
  | LV_ISlt
  | LV_ISle
  | LV_ISgt
  | LV_ISge
  | LV_IUlt
  | LV_IUle
  | LV_IUgt
  | LV_IUge

(** Floating-point comparison conditions. *)
type fcmp_cond =
  | LV_FOeq
  | LV_FOgt
  | LV_FOge
  | LV_FOlt
  | LV_FOle
  | LV_FOne
  | LV_FOrd

(** LLVM cast operations. *)
type cast_op =
  | LV_ZExt
  | LV_SExt
  | LV_Trunc
  | LV_FPExt
  | LV_FPTrunc
  | LV_FPToSI
  | LV_FPToUI
  | LV_SIToFP
  | LV_UIToFP
  | LV_PtrToInt
  | LV_IntToPtr
  | LV_BitCast

(** Right-hand side of an LLVM instruction. *)
type instr_rhs =
  | LV_IBinOp of ibinop * operand * operand
  | LV_FBinOp of fbinop * operand * operand
  | LV_ICmp of icmp_cond * operand * operand
  | LV_Alloca of lltype
  | LV_Alloca_n of { elem_ty : lltype; count : operand }
  | LV_Load of { ptr : operand; ty : lltype }
  | LV_Call of { fn : operand; args : operand list; ret_ty : lltype }
  | LV_Cast of cast_op * operand * lltype
  | LV_GEP of { base : operand; indices : operand list; result_ty : lltype }
  | LV_Phi of (operand * string) list
  | LV_Select of operand * operand * operand

(** An LLVM instruction (assign, store, or comment). *)
type instruction =
  | LV_Assign of operand * instr_rhs
  | LV_Store of operand * operand
  | LV_Comment of string

(** A block terminator. *)
type terminator =
  | LV_Ret of operand option
  | LV_Br of string
  | LV_CondBr of operand * string * string
  | LV_Switch of operand * string * (operand * string) list
  | LV_Unreachable

type block = {
  label : string;
  instructions : instruction list;
  terminator : terminator;
}
(** A basic block in LLVM LIR. *)

(** Linkage type for LLVM globals/functions. *)
type linkage = External | Internal | Private

type func = {
  name : string;
  ret_type : lltype;
  params : (lltype * string) list;
  blocks : block list;
  linkage : linkage;
}
(** An LLVM function definition. *)

type global_var = {
  g_name : string;
  g_type : lltype;
  g_init : constant option;
  g_linkage : linkage;
}
(** An LLVM global variable declaration. *)

type global_ctor = { priority : int; func : func }
(** An LLVM global constructor (init function). *)

type module_llvm = {
  target_triple : string option;
  type_defs : (string * lltype) list;
  declarations : (string * lltype) list;
  globals : global_var list;
  functions : func list;
  source_filename : string;
}
(** A complete LLVM module. *)

type module_ = module_llvm
(** Alias for [module_llvm]. *)
