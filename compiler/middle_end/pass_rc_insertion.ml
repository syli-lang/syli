open Syli_ir.Oir
open Syli_common
open Liveness

let void_ty () = { id = fresh_id (); ir_type = OR_Void }

let mk_rc_statement op (v : var) : statement =
  { id = fresh_id (); node = OR_RC_op { op; obj = v }; ty = void_ty () }

let mk_get_value_statement obj field_idx value_ty =
  let dst =
    {
      id = fresh_id ();
      name = "Sy_rc_tmp_" ^ string_of_int (fresh_id ());
      ty = value_ty;
    }
  in
  let statement =
    {
      id = fresh_id ();
      node =
        OR_Assign
          {
            dst;
            rvalue =
              {
                id = fresh_id ();
                node = OR_Object_get { obj = OR_OVar obj; field_idx; value_ty };
                ty = obj.ty;
              };
          };
      ty = value_ty;
    }
  in
  (dst, statement)

let is_ref ty = match ty.ir_type with OR_Obj _ -> true | _ -> false

let build_var_map (fn : function_oir) : var IntMap.t =
  let add (map : var IntMap.t) (v : var) = IntMap.add v.id v map in
  let map = List.fold_left add IntMap.empty fn.params in
  let map = List.fold_left add map fn.locals in
  List.fold_left
    (fun map (b : block) ->
      List.fold_left
        (fun map (stmt : statement) ->
          match stmt.node with
          | OR_Assign { dst; _ }
          | OR_Object_create { dst; _ }
          | OR_Call { dst; _ } ->
              add map dst
          | OR_Object_set { obj; _ } -> add map obj
          | OR_RC_op { obj; _ } -> add map obj
          | OR_Store_global _ | OR_Nop | OR_GC_cycle -> map)
        map b.statements)
    map fn.blocks

let build_param_ids (fn : function_oir) : IntSet.t =
  List.fold_left (fun s (v : var) -> IntSet.add v.id s) IntSet.empty fn.params

let process_block_statements (live_map : t) (var_map : var IntMap.t)
    (param_ids : IntSet.t) (statements : statement list)
    (terminator : terminator) : statement list =
  List.concat_map
    (fun (stmt : statement) ->
      let processed =
        match stmt.node with
        | OR_Object_set { obj; value_ty; field_idx } when is_ref value_ty ->
            let get_var, get_statement =
              mk_get_value_statement obj field_idx value_ty
            in
            [
              get_statement;
              mk_rc_statement OR_RC_decr get_var;
              mk_rc_statement OR_RC_check_release get_var;
              mk_rc_statement OR_RC_incr obj;
              stmt;
            ]
        | OR_Assign
            { dst; rvalue = { id = _; node = OR_Object_get { obj = _; _ } } }
          when is_ref dst.ty ->
            [ mk_rc_statement OR_RC_incr dst; stmt ]
        | OR_Store_global { value } -> (
            match value with
            | OR_OVar var when is_ref var.ty ->
                [ mk_rc_statement OR_RC_incr var; stmt ]
            | _ -> [ stmt ])
        | _ -> [ stmt ]
      in
      let dying =
        match IntMap.find_opt stmt.id live_map with
        | Some info ->
            IntSet.diff (IntSet.diff info.live_before info.live_after) param_ids
        | None -> IntSet.empty
      in
      let releases =
        IntSet.fold
          (fun vid acc ->
            match IntMap.find_opt vid var_map with
            | Some v ->
                mk_rc_statement OR_RC_decr v
                :: mk_rc_statement OR_RC_check_release v
                :: acc
            | None -> acc)
          dying []
      in
      let param_ret_acquire =
        match terminator with
        | { node = OR_Return (Some (OR_OVar var)) }
          when is_ref var.ty && IntSet.mem var.id param_ids ->
            [ mk_rc_statement OR_RC_incr var ]
        | _ -> []
      in
      List.flatten [ processed; releases; param_ret_acquire ])
    statements

let transform_function (fn : function_oir) : function_oir =
  let live_map = analyze fn in
  let var_map = build_var_map fn in
  let param_ids = build_param_ids fn in
  let blocks =
    List.map
      (fun (block : block) ->
        let statements =
          process_block_statements live_map var_map param_ids block.statements
            block.terminator
        in
        { block with statements })
      fn.blocks
  in
  { fn with blocks }

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
