open Syli_ir.Rir
open Syli_common
module Oir = Syli_ir.Oir
module Rir = Syli_ir.Rir

let void_ty () : ty = { id = Rir.fresh_id (); ty = RR_Void }

let void_dst () : var =
  { id = Rir.fresh_id (); fullname = "__sy_void"; ty = void_ty () }

let is_trackable (cp : Oir.cyclic_prop) : bool = cp <> Oir.Acyclic

let is_operand_trackable (op : operand) : bool =
  match op with
  | RR_OVar v -> (
      match v.ty.ty with RR_Obj_Ptr cp -> is_trackable cp | _ -> false)
  | _ -> false

let operand_cyclic_prop (op : operand) =
  match op with
  | RR_OVar v -> ( match v.ty.ty with RR_Obj_Ptr cp -> Some cp | _ -> None)
  | _ -> None

let notify_stmt (obj : operand) (value : operand) : statement =
  {
    id = Rir.fresh_id ();
    node =
      RR_Runtime_call
        {
          dst = void_dst ();
          call =
            {
              fn_name = RR_RT_object_check_mutation;
              args = [ obj; value ];
              ret_ty = None;
            };
        };
    ty = void_ty ();
  }

let global_ref_operand (global : qualified_name) (cp : Oir.cyclic_prop) :
    operand =
  RR_OVar
    {
      id = Rir.fresh_id ();
      fullname = global;
      ty = { id = Rir.fresh_id (); ty = RR_Obj_Ptr cp };
    }

let transform_statement (stmt : statement) : statement list =
  match stmt.node with
  | RR_Object_store { obj; value; value_ty; _ } ->
      if is_operand_trackable obj && is_operand_trackable value then
        [ stmt; notify_stmt obj value ]
      else [ stmt ]
  | RR_Store_global { global; value } -> (
      match operand_cyclic_prop value with
      | Some cp ->
          if is_trackable cp then
            [ stmt; notify_stmt (global_ref_operand global cp) value ]
          else [ stmt ]
      | None -> [ stmt ])
  | _ -> [ stmt ]

let transform_block (block : block) : block =
  let statements = List.concat_map transform_statement block.statements in
  { block with statements }

let transform_function (fn : function_rir) : function_rir =
  { fn with blocks = List.map transform_block fn.blocks }

let run (ctx : Pipeline_types.rir_ctx) : Pipeline_types.rir_ctx =
  {
    Pipeline_types.module_rir =
      {
        ctx.Pipeline_types.module_rir with
        functions = List.map transform_function ctx.module_rir.functions;
      };
    apply_gen_functions = List.map transform_function ctx.apply_gen_functions;
  }
