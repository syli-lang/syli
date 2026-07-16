open Syli_common

type t = Core | Cir_raw | Cir_mono | Cir | Oir | Rir | Llvm | Exec

let run (fmt : t) (filename : string) : string =
  let parsed = Syli_parsing.Utils.parse_file filename in
  let _infer_state, typed_items = Syli_typing.Infer.infer_program parsed in
  let desugared = Lower_ast_to_core.lower typed_items in
  let normalized () = Syli_core.Normalize.run desugared in
  let core_to_cir (core : Syli_core.Core_ast.program_core) =
    Lower_core_to_cir.lower { Pipeline_types.program = core }
  in
  let mono (ctx : Pipeline_types.cir_ctx) =
    Pass_monomorphize.monomorphize_program ctx
  in
  let cir_to_oir (ctx : Pipeline_types.cir_mono_ctx) =
    ctx |> Lower_cir_to_oir.lower
  in
  let oir_to_rir ctx = Lower_oir_to_rir.lower ctx in
  let prepared (ctx : Pipeline_types.rir_ctx) = Exec_unit.prepare_module ctx in
  let pp_oir (ctx : Pipeline_types.oir_ctx) =
    let functions = ctx.module_oir.functions @ ctx.apply_gen_functions in
    { ctx.module_oir with functions }
    |> Syli_ir.Oir_pretty_print.string_of_program
  in
  let pp_rir (ctx : Pipeline_types.rir_ctx) =
    let functions = ctx.module_rir.functions @ ctx.apply_gen_functions in
    { ctx.module_rir with functions }
    |> Syli_ir.Rir_pretty_print.string_of_program
  in
  let rir_and_llvm (ctx : Pipeline_types.rir_ctx) =
    ctx.module_rir.functions @ ctx.apply_gen_functions |> fun functions ->
    { ctx.module_rir with functions }
    |> Syli_target_llvm.Gen_llvm.lower_program |> Llvm_lir.module_to_string
  in
  match fmt with
  | Core -> normalized () |> Syli_core__Pp.string_of_program
  | Cir_raw ->
      normalized () |> core_to_cir |> fun ctx ->
      ctx.module_cir |> Syli_ir.Cir_pretty_print.string_of_program
  | Cir_mono ->
      normalized () |> core_to_cir |> mono |> fun ctx ->
      ctx.module_cir |> Syli_ir.Cir_pretty_print.string_of_program
  | Cir ->
      normalized () |> core_to_cir |> mono |> fun ctx ->
      ctx.module_cir |> Syli_ir.Cir_pretty_print.string_of_program
  | Oir ->
      normalized () |> core_to_cir |> mono |> cir_to_oir
      |> Pass_gc_cycle_insertion.run |> Pass_rc_insertion.run |> pp_oir
  | Rir ->
      normalized () |> core_to_cir |> mono |> cir_to_oir
      |> Pass_gc_cycle_insertion.run |> Pass_rc_insertion.run |> oir_to_rir
      |> pp_rir
  | Llvm ->
      normalized () |> core_to_cir |> mono |> cir_to_oir
      |> Pass_gc_cycle_insertion.run |> Pass_rc_insertion.run |> oir_to_rir
      |> prepared |> rir_and_llvm
  | Exec ->
      normalized () |> core_to_cir |> mono |> cir_to_oir
      |> Pass_gc_cycle_insertion.run |> Pass_rc_insertion.run |> oir_to_rir
      |> prepared |> rir_and_llvm
