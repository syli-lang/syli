open Syli_core.Core_ast
open Syli_ir.Cir
module Oir = Syli_ir.Oir
open Syli_common

type core_ctx = { program : program_core }
type cir_ctx = { module_cir : module_cir }
type cir_mono_ctx = { module_cir : module_cir; closure_graph : Closure_graph.t }

type oir_ctx = {
  module_oir : Oir.module_oir;
  apply_gen_functions : Oir.function_oir list;
}

type rir_ctx = {
  module_rir : Syli_ir.Rir.program_rir;
  apply_gen_functions : Syli_ir.Rir.function_rir list;
}
