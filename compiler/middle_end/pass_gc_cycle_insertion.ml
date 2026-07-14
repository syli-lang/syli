open Syli_ir.Oir
open Syli_common

let void_ty () = { id = fresh_id (); ir_type = OR_Void }

let gc_cycle_stmt () : statement =
  { id = fresh_id (); node = OR_GC_cycle; ty = void_ty () }

let nop_stmt () : statement =
  { id = fresh_id (); node = OR_Nop; ty = void_ty () }

let transform_block (block : block) : block =
  let statements =
    List.concat_map
      (fun (stmt : statement) ->
        match stmt.node with
        | OR_Object_create _ -> [ gc_cycle_stmt (); stmt; nop_stmt () ]
        | _ -> [ stmt ])
      block.statements
  in
  { block with statements }

let transform_function (fn : function_oir) : function_oir =
  { fn with blocks = List.map transform_block fn.blocks }

let run (ctx : Pipeline_types.oir_ctx) : Pipeline_types.oir_ctx =
  {
    Pipeline_types.module_oir =
      {
        ctx.Pipeline_types.module_oir with
        functions =
          List.map transform_function ctx.Pipeline_types.module_oir.functions;
      };
    apply_gen_functions = ctx.Pipeline_types.apply_gen_functions;
  }
