module Types = Types
module Helpers = Helpers
module Pp = Pp
module Builder = Builder

type lltype = Types.lltype
type const = Types.constant
type operand = Types.operand
type ibinop = Types.ibinop
type fbinop = Types.fbinop
type icmp_cond = Types.icmp_cond
type fcmp_cond = Types.fcmp_cond
type cast_op = Types.cast_op
type instr_rhs = Types.instr_rhs
type instruction = Types.instruction
type terminator = Types.terminator
type block = Types.block
type func = Types.func
type module_ = Types.module_llvm
type builder = Builder.builder

(* Helpers *)
let ty_of_operand = Helpers.ty_of_operand
let i64 = Helpers.i64
let i32 = Helpers.i32
let i16 = Helpers.i16
let i8 = Helpers.i8
let i1 = Helpers.i1
let f32 = Helpers.f32
let f64 = Helpers.f64
let null = Helpers.null
let local = Helpers.local
let global = Helpers.global
let string_of_lltype = Helpers.string_of_lltype
let string_of_ibinop = Helpers.string_of_ibinop
let string_of_fbinop = Helpers.string_of_fbinop
let string_of_icmp = Helpers.string_of_icmp
let string_of_fcmp = Helpers.string_of_fcmp
let string_of_cast_op = Helpers.string_of_cast_op
let string_of_operand = Helpers.string_of_operand
let string_of_typed_operand = Helpers.string_of_typed_operand

(* Builder *)
let create_module = Builder.create_module
let create_builder = Builder.create_builder
let with_block = Builder.with_block
let build_alloca = Builder.build_alloca
let build_load = Builder.build_load
let build_store = Builder.build_store
let build_ibinop = Builder.build_ibinop
let build_fbinop = Builder.build_fbinop
let build_icmp = Builder.build_icmp
let build_gep = Builder.build_gep
let build_call = Builder.build_call
let build_cast = Builder.build_cast
let build_phi = Builder.build_phi
let build_select = Builder.build_select
let build_br = Builder.build_br
let build_cond_br = Builder.build_cond_br
let build_ret = Builder.build_ret
let build_ret_void = Builder.build_ret_void
let add_comment = Builder.add_comment

(* Output *)
let func_to_string = Pp.func_to_string
let module_to_string = Pp.module_to_string
