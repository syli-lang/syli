(** LLVM IR builder.

    Provides imperative-style construction of LLVM IR modules with register
    allocation, basic block management, and instruction emission. *)

type module_ = Types.module_llvm

type gen_state = {
  next_reg : int;
  blocks : (string, Types.block) Hashtbl.t;
  current_block : string option;
}

type builder = { module_ : module_; state : gen_state }

val init_state : unit -> gen_state

val create_module :
  ?target_triple:string ->
  ?data_layout:'a ->
  ?source_filename:string ->
  unit ->
  Types.module_llvm

val create_builder : module_ -> builder
val fresh_reg : builder -> Types.lltype -> builder * Types.operand
val emit : builder -> Types.instruction -> builder
val set_terminator : builder -> Types.terminator -> builder
val with_block : builder -> string -> (builder -> builder * 'a) -> builder * 'a
val build_alloca : builder -> Types.lltype -> builder * Types.operand

val build_alloca_n :
  builder -> Types.lltype -> Types.operand -> builder * Types.operand

val build_load :
  builder -> Types.operand -> Types.lltype -> builder * Types.operand

val build_store : builder -> Types.operand -> Types.operand -> builder * unit

val build_ibinop :
  builder ->
  Types.ibinop ->
  Types.operand ->
  Types.operand ->
  builder * Types.operand

val build_fbinop :
  builder ->
  Types.fbinop ->
  Types.operand ->
  Types.operand ->
  builder * Types.operand

val build_icmp :
  builder ->
  Types.icmp_cond ->
  Types.operand ->
  Types.operand ->
  builder * Types.operand

val build_gep :
  builder ->
  Types.operand ->
  Types.operand list ->
  Types.lltype ->
  builder * Types.operand

val build_call :
  builder ->
  Types.operand ->
  Types.operand list ->
  builder * Types.operand option

val build_cast :
  builder ->
  Types.cast_op ->
  Types.operand ->
  Types.lltype ->
  builder * Types.operand

val build_phi :
  builder ->
  Types.lltype ->
  (Types.operand * string) list ->
  builder * Types.operand

val build_select :
  builder ->
  Types.operand ->
  Types.operand ->
  Types.operand ->
  builder * Types.operand

val build_br : builder -> string -> builder
val build_cond_br : builder -> Types.operand -> string -> string -> builder
val build_ret : builder -> Types.operand -> builder
val build_ret_void : builder -> builder
val add_comment : builder -> string -> builder
