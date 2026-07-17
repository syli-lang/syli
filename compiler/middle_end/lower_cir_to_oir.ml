(** Conversion from CIR (Closure IR) to OIR (Object IR).

    Key transformations:
    - Cir.CR_Make_closure → object_create + field stores
    - Cir.CR_Partial_apply → object_create + field stores (chain via parent ptr,
      no copy)
    - Apply call target → Direct_fnptr (resolved to accum function)
    - Cir.CR_Arrow type → pointer type
    - Cir.CR_GenericTyp → error (should be monomorphized away) *)

open Syli_common
open Syli_ir.Oir
open Closure_graph
module Cir = Syli_ir.Cir
module Oir = Syli_ir.Oir

type ctx = {
  closure_graph : Closure_graph.t;
  trampolines : function_oir StringMap.t;
  var_ids : Oir.var IntMap.t (* Cir var id → Oir var with fresh Oir id *);
  block_ids : int IntMap.t (* Cir block id → Oir block id *);
}

(* Counters for generating unique temporary variable names *)
let tmp_counter = ref 0

let fresh_var (name : string) (ty : Oir.ty) : Oir.var =
  let idx = !tmp_counter in
  tmp_counter := idx + 1;
  { id = Oir.fresh_id (); name = name ^ "_" ^ string_of_int idx; ty }

let fresh_global_id = Cir.fresh_id

(* Helper constructors *)
let i64_ty () : Oir.ty = { id = fresh_global_id (); ir_type = Oir.OR_I64 }
let fn_ptr_ty () : Oir.ty = { id = fresh_global_id (); ir_type = Oir.OR_FnPtr }
let void_ty () : Oir.ty = { id = fresh_global_id (); ir_type = Oir.OR_Void }
let i32_ty () : Oir.ty = { id = fresh_global_id (); ir_type = Oir.OR_I32 }

let int_operand (value : int) : Oir.operand =
  Oir.OR_OConstant (Oir.OR_IntLit (string_of_int value), i32_ty ())

let int64_operand (value : int64) : Oir.operand =
  Oir.OR_OConstant (Oir.OR_IntLit (Int64.to_string value), i64_ty ())

let var_operand (v : Oir.var) : Oir.operand = Oir.OR_OVar v
let null_operand (ty : Oir.ty) : Oir.operand = Oir.OR_OConstant (Oir.OR_Null, ty)

(* Conversion helpers for types that differ between Cir and Oir *)
let lower_binop (op : Cir.binop) : Oir.binop =
  match op with
  | Cir.CR_Add -> OR_Add
  | Cir.CR_Sub -> OR_Sub
  | Cir.CR_Mul -> OR_Mul
  | Cir.CR_Div -> OR_Div
  | Cir.CR_Mod -> OR_Mod
  | Cir.CR_Eq -> OR_Eq
  | Cir.CR_Ne -> OR_Ne
  | Cir.CR_Lt -> OR_Lt
  | Cir.CR_Le -> OR_Le
  | Cir.CR_Gt -> OR_Gt
  | Cir.CR_Ge -> OR_Ge
  | Cir.CR_BitAnd -> OR_BitAnd
  | Cir.CR_BitOr -> OR_BitOr
  | Cir.CR_BitXor -> OR_BitXor
  | Cir.CR_Shl -> OR_Shl
  | Cir.CR_Shr -> OR_Shr
  | Cir.CR_And -> OR_And
  | Cir.CR_Or -> OR_Or

let lower_unop (op : Cir.unop) : Oir.unop =
  match op with
  | Cir.CR_Neg -> OR_Neg
  | Cir.CR_Not -> OR_Not
  | Cir.CR_BitNot -> OR_BitNot

let lower_visibility (v : Cir.visibility) : Oir.visibility =
  match v with Cir.CR_Public -> OR_Public | Cir.CR_Private -> OR_Private

(* Type conversion helpers *)

let rec lower_ir_type (t : Cir.ir_type) : Oir.ir_type =
  match t with
  | Cir.CR_Bool -> Oir.OR_Bool
  | Cir.CR_I64 -> Oir.OR_I64
  | Cir.CR_I32 -> Oir.OR_I32
  | Cir.CR_I16 -> Oir.OR_I16
  | Cir.CR_I8 -> Oir.OR_I8
  | Cir.CR_U64 -> Oir.OR_U64
  | Cir.CR_U32 -> Oir.OR_U32
  | Cir.CR_U16 -> Oir.OR_U16
  | Cir.CR_U8 -> Oir.OR_U8
  | Cir.CR_Float -> Oir.OR_Float
  | Cir.CR_Double -> Oir.OR_Double
  | Cir.CR_FnPtr -> Oir.OR_FnPtr
  | Cir.CR_Obj { named; args } ->
      Oir.OR_Obj { named; args = List.map lower_ty args }
  | Cir.CR_Obj_Ptr inner -> Oir.OR_Obj_Ptr (lower_ty inner)
  | Cir.CR_Char -> Oir.OR_Char
  | Cir.CR_Str -> Oir.OR_Str
  | Cir.CR_Void -> Oir.OR_Void
  | Cir.CR_GenericTyp _ ->
      failwith
        "Cir.CR_GenericTyp should be monomorphized before lowering to OIR"
  | Cir.CR_Arrow _ ->
      Oir.OR_Obj_Ptr { id = fresh_global_id (); ir_type = Oir.OR_Void }

and lower_ty (t : Cir.ty) : Oir.ty =
  { id = fresh_global_id (); ir_type = lower_ir_type t.ir_type }

let lower_var (ctx : ctx) (v : Cir.var) : ctx * Oir.var =
  match IntMap.find_opt v.id ctx.var_ids with
  | Some v' -> (ctx, v')
  | None ->
      let v' = { id = Oir.fresh_id (); name = v.name; ty = lower_ty v.ty } in
      ({ ctx with var_ids = IntMap.add v.id v' ctx.var_ids }, v')

let lower_constant (c : Cir.constant) : Oir.constant =
  match c with
  | Cir.CR_IntLit s -> Oir.OR_IntLit s
  | Cir.CR_FloatLit s -> Oir.OR_FloatLit s
  | Cir.CR_BoolLit s -> Oir.OR_BoolLit s
  | Cir.CR_Null -> Oir.OR_Null
  | Cir.CR_StringLit s -> Oir.OR_StringLit s
  | Cir.CR_CharLit s -> Oir.OR_CharLit s

let lower_operand (ctx : ctx) (op : Cir.operand) : ctx * Oir.operand =
  match op with
  | Cir.CR_OConstant (c, ty) ->
      (ctx, Oir.OR_OConstant (lower_constant c, lower_ty ty))
  | Cir.CR_OVar v ->
      let ctx, v' = lower_var ctx v in
      (ctx, Oir.OR_OVar v')

let lower_call_target (ctx : ctx) (t : Cir.call_target) : ctx * Oir.call_target
    =
  match t with
  | Direct name -> (ctx, Direct name)
  | Direct_fn_ptr { ptr = v } ->
      let ctx, v' = lower_var ctx v in
      (ctx, Direct_fn_ptr { ptr = v' })
  | Apply _ ->
      failwith
        "Apply{closure} should have been rewritten by lower_cir_to_oir before \
         lowering to OIR"

let lower_terminator (ctx : ctx) (term : Cir.terminator) : ctx * Oir.terminator
    =
  let lookup_block id =
    match IntMap.find_opt id ctx.block_ids with
    | Some id' -> id'
    | None -> failwith ("lower_terminator: unknown block id " ^ string_of_int id)
  in
  let ctx, node =
    match term.node with
    | Cir.CR_Goto id -> (ctx, Oir.OR_Goto (lookup_block id))
    | Cir.CR_Switch { scrutinee; cases; default_block } ->
        let ctx, scrutinee' = lower_var ctx scrutinee in
        ( ctx,
          Oir.OR_Switch
            {
              scrutinee = scrutinee';
              cases =
                List.map
                  (fun (c : Cir.switch_case_node) ->
                    {
                      Oir.value = c.value;
                      target_block = lookup_block c.target_block;
                    })
                  cases;
              default_block = Option.map lookup_block default_block;
            } )
    | Cir.CR_CondBr { cond; then_block; else_block } ->
        let ctx, cond' = lower_var ctx cond in
        ( ctx,
          Oir.OR_CondBr
            {
              cond = cond';
              then_block = lookup_block then_block;
              else_block = lookup_block else_block;
            } )
    | Cir.CR_Return op ->
        let ctx, op' =
          match op with
          | Some o ->
              let ctx, o' = lower_operand ctx o in
              (ctx, Some o')
          | None -> (ctx, None)
        in
        (ctx, Oir.OR_Return op')
  in
  (ctx, { id = fresh_global_id (); node })

let lower_object_layout (layout : Cir.object_layout) : Oir.object_layout =
  match layout with
  | Cir.CR_Record { field_count; field_types; tag_variant } ->
      Oir.OR_Record
        {
          field_count;
          field_types = List.map lower_ty field_types;
          tag_variant;
        }
  | Cir.CR_Array { element_ty; tag_variant } ->
      Oir.OR_Array { element_ty = lower_ty element_ty; tag_variant }

let rvalue_of_cir (ctx : ctx) (rv : Cir.rvalue) : ctx * Oir.rvalue =
  let oir_ty = lower_ty rv.ty in
  let ctx, node =
    match rv.node with
    | Cir.CR_BinOp { op; lhs; rhs } ->
        let ctx, lhs' = lower_operand ctx lhs in
        let ctx, rhs' = lower_operand ctx rhs in
        (ctx, Oir.OR_BinOp { op = lower_binop op; lhs = lhs'; rhs = rhs' })
    | Cir.CR_UnOp { op; operand } ->
        let ctx, operand' = lower_operand ctx operand in
        (ctx, Oir.OR_UnOp { op = lower_unop op; operand = operand' })
    | Cir.CR_Object_get { obj; field_idx; value_ty } ->
        let ctx, obj' = lower_operand ctx obj in
        let ctx, field_idx' = lower_operand ctx field_idx in
        ( ctx,
          Oir.OR_Object_get
            { obj = obj'; field_idx = field_idx'; value_ty = lower_ty value_ty }
        )
    | Cir.CR_Object_length { obj } ->
        let ctx, obj' = lower_operand ctx obj in
        (ctx, Oir.OR_Object_length { obj = obj' })
    | Cir.CR_Object_get_tag { obj } ->
        let ctx, obj' = lower_operand ctx obj in
        (ctx, Oir.OR_Object_get_tag { obj = obj' })
    | Cir.CR_Cast { src; to_ty } ->
        let ctx, src' = lower_operand ctx src in
        (ctx, Oir.OR_Cast { src = src'; to_ty = lower_ty to_ty })
    | Cir.CR_Move { src } ->
        let ctx, src' = lower_operand ctx src in
        (ctx, Oir.OR_Move { src = src' })
    | Cir.CR_Addr_fn { fn } -> (ctx, Oir.OR_Addr_fn { fn })
  in
  (ctx, { id = fresh_global_id (); node; ty = oir_ty })

(* SIR type helpers for constructing layouts *)
let sir_fn_ptr_ty : Cir.ty = { id = fresh_global_id (); ir_type = Cir.CR_FnPtr }
let sir_i64_ty : Cir.ty = { id = fresh_global_id (); ir_type = Cir.CR_I64 }

let sir_void_ptr_ty : Cir.ty =
  {
    id = fresh_global_id ();
    ir_type = Cir.CR_Obj_Ptr { id = fresh_global_id (); ir_type = Cir.CR_Void };
  }

let sir_operand_ty (op : Cir.operand) : Cir.ty =
  match op with Cir.CR_OConstant (_, ty) -> ty | Cir.CR_OVar v -> v.ty

let is_arrow_ty (t : Cir.ty) : bool =
  match t.ir_type with Cir.CR_Arrow _ -> true | _ -> false

let make_closure_apply_gen_functions gen_functions closure_graph ~node_id
    ~free_vars_len ~fn_name =
  let make_closure_node = IntMap.find node_id closure_graph.graph.nodes in
  let specializations =
    match
      IntMap.find_opt node_id closure_graph.make_closure_fn_specializations
    with
    | Some specializations ->
        List.map
          (fun spe ->
            ( spe.dispatch_cumul,
              spe.fn_name,
              List.map lower_ty spe.arg_tys,
              lower_ty spe.ret_ty ))
          specializations
    | None -> failwith "any make_closure should have it owns specializations"
  in
  let base_ret_ty =
    match
      IntMap.find_opt make_closure_node.id closure_graph.concrete_ret_ty
    with
    | Some ret_ty -> lower_ty ret_ty
    | None -> i64_ty ()
  in
  let ret_ty =
    if IntSet.mem node_id closure_graph.generic_nodes then i64_ty ()
    else base_ret_ty
  in
  let arg_tys_len = List.length make_closure_node.arg_tys in
  let stored_args_size = arg_tys_len + free_vars_len in
  let is_generic = IntSet.mem node_id closure_graph.generic_nodes in
  let needs_cast spe_ret =
    is_generic && spe_ret.Oir.ir_type <> ret_ty.Oir.ir_type
  in
  (* Generate the wrappers (for the accum dispatch to call) *)
  let gen_functions =
    List.fold_left
      (fun acc
           ((_, fn_name, param_tys, spe_ret_ty) :
             int * string * Oir.ty list * Oir.ty) ->
        if needs_cast spe_ret_ty then
          let wrapper_name =
            Gen_closure_function.apply_wrapper_name_cast ~fn_name ~param_tys
              ~cast_from:spe_ret_ty
          in
          StringMap.update wrapper_name
            (fun wrapper_name_opt ->
              match wrapper_name_opt with
              | None ->
                  Option.some
                  @@ Gen_closure_function.build_apply_wrapper_cast ~fn_name
                       ~param_tys ~cast_from:spe_ret_ty
              | Some _ as existing -> existing)
            acc
        else
          let wrapper_name =
            Gen_closure_function.apply_wrapper_name ~fn_name ~param_tys
              ~ret_ty:spe_ret_ty
          in
          StringMap.update wrapper_name
            (fun wrapper_name_opt ->
              match wrapper_name_opt with
              | None ->
                  Option.some
                  @@ Gen_closure_function.build_apply_wrapper ~fn_name
                       ~param_tys ~ret_ty:spe_ret_ty
              | Some _ as existing -> existing)
            acc)
      gen_functions specializations
  in
  (* Generate the make_closure accum dispatch function *)
  let gen_fn_name, gen_functions =
    match specializations with
    | (dispatch_cumul, fn_name, tys, _) :: [] ->
        let closure_accum_name =
          Gen_closure_function.make_closure_accum_name ~fn_name
            make_closure_node.id ~ret_ty
        in
        ( closure_accum_name,
          StringMap.update closure_accum_name
            (function
              | Some _ as existing -> existing
              | None ->
                  Option.some
                  @@ Gen_closure_function.build_make_closure_accum ~fn_name
                       ~stored_args_size
                       ~args_size:
                         (List.length make_closure_node.remaining_arg_tys)
                       ~specializations:tys ~ret_ty node_id)
            gen_functions )
    | (dispatch_cumul, fn_name, tys, _) :: _ ->
        let closure_accum_name =
          Gen_closure_function.make_closure_accum_dispatch_name
            make_closure_node.id ~ret_ty
        in
        ( closure_accum_name,
          StringMap.update closure_accum_name
            (function
              | Some _ as existing -> existing
              | None ->
                  Option.some
                  @@ Gen_closure_function.build_make_closure_accum_dispatch
                       ~stored_args_size
                       ~args_size:
                         (List.length make_closure_node.remaining_arg_tys)
                       ~specializations ~ret_ty node_id)
            gen_functions )
    | [] -> failwith "any make_closure should have at least one specialization"
  in
  (gen_functions, gen_fn_name)

(** Lower a Cir.CR_Make_closure statement into OIR statements.

    Layout (matching gen_closure_function.ml): [0]=accum_fn,
    [1+]=stored_args(free_vars + captured_args) *)
let lower_make_closure (ctx : ctx) (dst : Cir.var) (free_vars : Cir.var list)
    (captured_args : Cir.operand list) (fn_name : string) :
    ctx * Oir.statement list =
  let ctx, oir_dst = lower_var ctx dst in
  let free_var_count = List.length free_vars in
  let captured_count = List.length captured_args in
  let stored_args_size = free_var_count + captured_count in
  let trampolines, accum_fn_name =
    make_closure_apply_gen_functions ctx.trampolines ctx.closure_graph
      ~node_id:dst.id ~free_vars_len:(List.length free_vars) ~fn_name
  in
  let ctx = { ctx with trampolines } in
  let total_fields = 1 + stored_args_size in
  let field_types : Cir.ty list =
    sir_fn_ptr_ty :: List.init stored_args_size (fun _ -> sir_i64_ty)
  in
  let layout =
    Cir.CR_Record { field_count = total_fields; field_types; tag_variant = 0 }
  in
  let size_op = int_operand total_fields in
  let create_stmt_node =
    Oir.OR_Object_create
      {
        dst = oir_dst;
        size = size_op;
        layout = lower_object_layout layout;
        initializer_fn = None;
      }
  in
  (* Set clos[0] = accum_fn *)
  let accum_var = fresh_var "Sy_accum_fn" (fn_ptr_ty ()) in
  let accum_addr_stmt =
    {
      id = fresh_global_id ();
      node =
        Oir.OR_Assign
          {
            dst = accum_var;
            rvalue =
              {
                id = fresh_global_id ();
                node = Oir.OR_Addr_fn { fn = accum_fn_name };
                ty = fn_ptr_ty ();
              };
          };
      ty = fn_ptr_ty ();
    }
  in
  let set_accum_stmt =
    {
      id = fresh_global_id ();
      node =
        Oir.OR_Object_set
          {
            obj = oir_dst;
            field_idx = int_operand 0;
            value = var_operand accum_var;
            value_ty = fn_ptr_ty ();
          };
      ty = fn_ptr_ty ();
    }
  in
  (* Store stored_args at field index 1 *)
  let stored_operands =
    List.map (fun (v : Cir.var) -> Cir.CR_OVar v) free_vars @ captured_args
  in
  let ctx, lowered_operands =
    List.fold_left_map
      (fun ctx arg -> lower_operand ctx arg)
      ctx stored_operands
  in
  let stored_arg_stmts =
    List.mapi
      (fun i value ->
        {
          id = fresh_global_id ();
          node =
            Oir.OR_Object_set
              {
                obj = oir_dst;
                field_idx = int_operand (1 + i);
                value;
                value_ty = i64_ty ();
              };
          ty = fn_ptr_ty ();
        })
      lowered_operands
  in
  ( ctx,
    [
      { id = fresh_global_id (); node = create_stmt_node; ty = fn_ptr_ty () };
      accum_addr_stmt;
      set_accum_stmt;
    ]
    @ stored_arg_stmts )

let partial_gen_apply_functions gen_functions closure_graph node_dst_id =
  let node = IntMap.find node_dst_id closure_graph.graph.nodes in
  let dispatch_id_possibilities =
    IntMap.find_opt node_dst_id closure_graph.node_dispatch_possibilities
    |> Option.value ~default:[]
  in
  let stored_args_size = List.length node.arg_tys in
  let args_size = List.length node.remaining_arg_tys in
  let base_ret_ty =
    match IntMap.find_opt node_dst_id closure_graph.concrete_ret_ty with
    | Some ty -> lower_ty ty
    | None -> i64_ty ()
  in
  let ret_ty =
    if IntSet.mem node_dst_id closure_graph.generic_nodes then i64_ty ()
    else base_ret_ty
  in
  let is_dispatch, gen_fn_name, gen_functions =
    if List.exists (fun x -> x > 0) dispatch_id_possibilities then
      let closure_accum_name =
        Gen_closure_function.partial_closure_accum_dispatch_name
          ~stored_args_size ~args_size ~ret_ty
      in
      ( true,
        closure_accum_name,
        StringMap.update closure_accum_name
          (function
            | Some _ as existing -> existing
            | None ->
                Option.some
                @@ Gen_closure_function.build_partial_closure_accum_dispatch
                     ~stored_args_size ~args_size ret_ty)
          gen_functions )
    else
      let closure_accum_name =
        Gen_closure_function.partial_closure_accum_name ~stored_args_size
          ~args_size ~ret_ty
      in
      ( false,
        closure_accum_name,
        StringMap.update closure_accum_name
          (function
            | Some _ as existing -> existing
            | None ->
                Option.some
                @@ Gen_closure_function.build_partial_closure_accum
                     ~stored_args_size ~args_size ret_ty)
          gen_functions )
  in
  (is_dispatch, gen_fn_name, gen_functions)

(** Lower a Cir.CR_Partial_apply statement into OIR statements.

    Layouts (matching gen_closure_function.ml):

    Non-dispatch: [0]=accum_fn, [1]=parent, [2+]=new_args

    Dispatch: [0]=accum_fn, [1]=dispatch_edge, [2]=parent, [3+]=new_args

    Only stores the new arguments at this step (no copy of inherited args).
    Chain traversal happens via the parent pointer at runtime. *)
let lower_partial_apply (ctx : ctx) (dst : Cir.var) (closure : Cir.var)
    (new_args : Cir.operand list) : ctx * Oir.statement list =
  let ctx, oir_dst = lower_var ctx dst in
  let new_args_count = List.length new_args in
  let is_dispatch, accum_fn_name, trampolines =
    partial_gen_apply_functions ctx.trampolines ctx.closure_graph dst.id
  in
  let ctx = { ctx with trampolines } in
  let has_dispatch = if is_dispatch then 1 else 0 in
  let total_fields = 2 + has_dispatch + new_args_count in
  let sir_field_types : Cir.ty list =
    [ sir_fn_ptr_ty ]
    @ (if is_dispatch then [ sir_i64_ty ] else [])
    @ [ sir_void_ptr_ty ]
    @ List.init new_args_count (fun _ -> sir_i64_ty)
  in
  let layout =
    Cir.CR_Record
      {
        field_count = total_fields;
        field_types = sir_field_types;
        tag_variant = 0;
      }
  in
  let size_op = int_operand total_fields in
  let create_stmt_node =
    Oir.OR_Object_create
      {
        dst = oir_dst;
        size = size_op;
        layout = lower_object_layout layout;
        initializer_fn = None;
      }
  in
  (* Set clos[0] = accum_fn *)
  let accum_var = fresh_var "Sy_accum_fn" (fn_ptr_ty ()) in
  let accum_addr_stmt =
    {
      id = fresh_global_id ();
      node =
        Oir.OR_Assign
          {
            dst = accum_var;
            rvalue =
              {
                id = fresh_global_id ();
                node = Oir.OR_Addr_fn { fn = accum_fn_name };
                ty = fn_ptr_ty ();
              };
          };
      ty = fn_ptr_ty ();
    }
  in
  let set_accum_stmt =
    {
      id = fresh_global_id ();
      node =
        Oir.OR_Object_set
          {
            obj = oir_dst;
            field_idx = int_operand 0;
            value = var_operand accum_var;
            value_ty = fn_ptr_ty ();
          };
      ty = fn_ptr_ty ();
    }
  in
  (* If dispatch: set clos[1] = dispatch_edge *)
  let dispatch_edge_stmts, parent_idx, args_idx =
    if is_dispatch then
      let edge_weight =
        Closure_graph.dispatch_edge_weight ctx.closure_graph ~src:closure.id
          ~target:dst.id
      in
      let stmts =
        [
          {
            id = fresh_global_id ();
            node =
              Oir.OR_Object_set
                {
                  obj = oir_dst;
                  field_idx = int_operand 1;
                  value = int64_operand (Int64.of_int edge_weight);
                  value_ty = i64_ty ();
                };
            ty = fn_ptr_ty ();
          };
        ]
      in
      (stmts, 2, 3)
    else ([], 1, 2)
  in
  (* Set parent pointer *)
  let ctx, closure_operand = lower_operand ctx (Cir.CR_OVar closure) in
  let set_parent_stmt =
    {
      id = fresh_global_id ();
      node =
        Oir.OR_Object_set
          {
            obj = oir_dst;
            field_idx = int_operand parent_idx;
            value = closure_operand;
            value_ty = lower_ty sir_void_ptr_ty;
          };
      ty = fn_ptr_ty ();
    }
  in
  (* Store new args starting at args_idx *)
  let ctx, lowered_args =
    List.fold_left_map (fun ctx arg -> lower_operand ctx arg) ctx new_args
  in
  let store_new_arg_stmts =
    List.mapi
      (fun i value ->
        {
          id = fresh_global_id ();
          node =
            Oir.OR_Object_set
              {
                obj = oir_dst;
                field_idx = int_operand (args_idx + i);
                value;
                value_ty = i64_ty ();
              };
          ty = fn_ptr_ty ();
        })
      lowered_args
  in
  ( ctx,
    [
      { id = fresh_global_id (); node = create_stmt_node; ty = fn_ptr_ty () };
      accum_addr_stmt;
      set_accum_stmt;
    ]
    @ dispatch_edge_stmts @ [ set_parent_stmt ] @ store_new_arg_stmts )

(** Lower a Cir.CR_Cast on an arrow type into a pass-through closure when
    dispatch > 0.

    Layout: [0]=accum_fn, [1]=dispatch_edge, [2]=parent

    Chains to the parent (Make_closure root) with accumulated dispatch_id. *)
let lower_cast_closure (ctx : ctx) (dst : Cir.var) (src : Cir.var) :
    ctx * Oir.statement list =
  let ctx, oir_dst = lower_var ctx dst in
  let is_dispatch, accum_fn_name, trampolines =
    partial_gen_apply_functions ctx.trampolines ctx.closure_graph dst.id
  in
  let ctx = { ctx with trampolines } in
  let has_dispatch = if is_dispatch then 1 else 0 in
  let total_fields = 2 + has_dispatch in
  let sir_field_types : Cir.ty list =
    [ sir_fn_ptr_ty ]
    @ (if is_dispatch then [ sir_i64_ty ] else [])
    @ [ sir_void_ptr_ty ]
  in
  let layout =
    Cir.CR_Record
      {
        field_count = total_fields;
        field_types = sir_field_types;
        tag_variant = 0;
      }
  in
  let size_op = int_operand total_fields in
  let create_stmt_node =
    Oir.OR_Object_create
      {
        dst = oir_dst;
        size = size_op;
        layout = lower_object_layout layout;
        initializer_fn = None;
      }
  in
  (* Set clos[0] = accum_fn *)
  let accum_var = fresh_var "Sy_accum_fn" (fn_ptr_ty ()) in
  let accum_addr_stmt =
    {
      id = fresh_global_id ();
      node =
        Oir.OR_Assign
          {
            dst = accum_var;
            rvalue =
              {
                id = fresh_global_id ();
                node = Oir.OR_Addr_fn { fn = accum_fn_name };
                ty = fn_ptr_ty ();
              };
          };
      ty = fn_ptr_ty ();
    }
  in
  let set_accum_stmt =
    {
      id = fresh_global_id ();
      node =
        Oir.OR_Object_set
          {
            obj = oir_dst;
            field_idx = int_operand 0;
            value = var_operand accum_var;
            value_ty = fn_ptr_ty ();
          };
      ty = fn_ptr_ty ();
    }
  in
  (* If dispatch: set clos[1] = dispatch_edge *)
  let dispatch_edge_stmts, parent_idx =
    if is_dispatch then
      let edge_weight =
        Closure_graph.dispatch_edge_weight ctx.closure_graph ~src:src.id
          ~target:dst.id
      in
      let stmts =
        [
          {
            id = fresh_global_id ();
            node =
              Oir.OR_Object_set
                {
                  obj = oir_dst;
                  field_idx = int_operand 1;
                  value = int64_operand (Int64.of_int edge_weight);
                  value_ty = i64_ty ();
                };
            ty = fn_ptr_ty ();
          };
        ]
      in
      (stmts, 2)
    else ([], 1)
  in
  (* Set parent pointer *)
  let ctx, src_operand = lower_operand ctx (Cir.CR_OVar src) in
  let set_parent_stmt =
    {
      id = fresh_global_id ();
      node =
        Oir.OR_Object_set
          {
            obj = oir_dst;
            field_idx = int_operand parent_idx;
            value = src_operand;
            value_ty = lower_ty sir_void_ptr_ty;
          };
      ty = fn_ptr_ty ();
    }
  in
  ( ctx,
    [
      { id = fresh_global_id (); node = create_stmt_node; ty = fn_ptr_ty () };
      accum_addr_stmt;
      set_accum_stmt;
    ]
    @ dispatch_edge_stmts @ [ set_parent_stmt ] )

let statement_of_cir (ctx : ctx) (stmt : Cir.statement) :
    ctx * Oir.statement list =
  match stmt.node with
  | Cir.CR_Make_closure
      { dst; free_vars; captured_args; fn; initializer_fn = _ } ->
      lower_make_closure ctx dst free_vars captured_args fn
  | Cir.CR_Partial_apply { dst; closure; new_args } ->
      lower_partial_apply ctx dst closure new_args
  | Cir.CR_Assign
      { dst; rvalue = { node = Cir.CR_Cast { src = Cir.CR_OVar c; _ }; _ }; _ }
    when is_arrow_ty dst.ty && IntMap.mem dst.id ctx.closure_graph.graph.nodes
    ->
      lower_cast_closure ctx dst c
  | Cir.CR_Assign { dst; rvalue = { node = Cir.CR_Move { src }; _ } as rvalue }
    ->
      let ctx, dst' = lower_var ctx dst in
      let ctx, rv' = rvalue_of_cir ctx rvalue in
      ( ctx,
        [
          {
            id = fresh_global_id ();
            node = Oir.OR_Assign { dst = dst'; rvalue = rv' };
            ty = lower_ty stmt.ty;
          };
        ] )
  | Cir.CR_Assign { dst; rvalue } ->
      let ctx, dst' = lower_var ctx dst in
      let ctx, rv' = rvalue_of_cir ctx rvalue in
      ( ctx,
        [
          {
            id = fresh_global_id ();
            node = Oir.OR_Assign { dst = dst'; rvalue = rv' };
            ty = lower_ty stmt.ty;
          };
        ] )
  | Cir.CR_Object_set { obj; field_idx; value; value_ty } ->
      let ctx, obj' = lower_var ctx obj in
      let ctx, field_idx' = lower_operand ctx field_idx in
      let ctx, value' = lower_operand ctx value in
      ( ctx,
        [
          {
            id = fresh_global_id ();
            node =
              Oir.OR_Object_set
                {
                  obj = obj';
                  field_idx = field_idx';
                  value = value';
                  value_ty = lower_ty value_ty;
                };
            ty = lower_ty stmt.ty;
          };
        ] )
  | Cir.CR_Object_create { dst; size; layout } ->
      let ctx, dst' = lower_var ctx dst in
      let ctx, size' = lower_operand ctx size in
      ( ctx,
        [
          {
            id = fresh_global_id ();
            node =
              Oir.OR_Object_create
                {
                  dst = dst';
                  size = size';
                  layout = lower_object_layout layout;
                  initializer_fn = None;
                };
            ty = lower_ty stmt.ty;
          };
        ] )
  | Cir.CR_Call { dst; target = Apply { closure }; args } ->
      let ctx, oir_dst = lower_var ctx dst in
      let is_void = dst.ty.Cir.ir_type = Cir.CR_Void in
      let accum_ptr = fresh_var "Sy_accum_ptr" (fn_ptr_ty ()) in
      let ctx, closure_op = lower_operand ctx (Cir.CR_OVar closure) in
      let load_accum_stmt =
        {
          id = fresh_global_id ();
          node =
            Oir.OR_Assign
              {
                dst = accum_ptr;
                rvalue =
                  {
                    id = fresh_global_id ();
                    node =
                      Oir.OR_Object_get
                        {
                          obj = closure_op;
                          field_idx = int_operand 0;
                          value_ty = fn_ptr_ty ();
                        };
                    ty = fn_ptr_ty ();
                  };
              };
          ty = fn_ptr_ty ();
        }
      in
      (* Cast args to i64 for accum function (it expects all args as i64) *)
      let make_tmp_i64_var () : Oir.var =
        let idx = !tmp_counter in
        tmp_counter := idx + 1;
        let id = -(idx + 1) in
        { Oir.id; name = "Sy_apply_cast_" ^ string_of_int idx; ty = i64_ty () }
      in
      let ctx, cast_results =
        List.fold_left_map
          (fun ctx (arg : Cir.operand) ->
            let ctx, oir_arg = lower_operand ctx arg in
            let arg_ty =
              match oir_arg with
              | Oir.OR_OVar v -> v.ty
              | Oir.OR_OConstant (_, ty) -> ty
            in
            match arg_ty.Oir.ir_type with
            | Oir.OR_I64 -> (ctx, ([], oir_arg))
            | _ ->
                let cast_var = make_tmp_i64_var () in
                let cast_stmt =
                  {
                    id = fresh_global_id ();
                    node =
                      Oir.OR_Assign
                        {
                          dst = cast_var;
                          rvalue =
                            {
                              id = fresh_global_id ();
                              node =
                                Oir.OR_Cast { src = oir_arg; to_ty = i64_ty () };
                              ty = i64_ty ();
                            };
                        };
                    ty = i64_ty ();
                  }
                in
                (ctx, ([ cast_stmt ], Oir.OR_OVar cast_var)))
          ctx args
      in
      let cast_stmts = List.concat_map fst cast_results in
      let casted_args = List.map snd cast_results in
      let call_args =
        casted_args
        @ [
            closure_op;
            int64_operand
              (Int64.of_int
                 (Closure_graph.dispatch_edge_weight ctx.closure_graph
                    ~src:closure.id ~target:dst.id));
          ]
      in
      let is_generic = IntSet.mem closure.id ctx.closure_graph.generic_nodes in
      let needs_result_cast =
        (not is_void) && is_generic && oir_dst.ty.Oir.ir_type <> Oir.OR_I64
      in
      let call_dst, extra_cast_stmt =
        if needs_result_cast then
          let tmp = fresh_var "Sy_apply_tmp" (i64_ty ()) in
          let cast_stmt =
            {
              id = fresh_global_id ();
              node =
                Oir.OR_Assign
                  {
                    dst = oir_dst;
                    rvalue =
                      {
                        id = fresh_global_id ();
                        node =
                          Oir.OR_Cast
                            { src = Oir.OR_OVar tmp; to_ty = oir_dst.ty };
                        ty = oir_dst.ty;
                      };
                  };
              ty = oir_dst.ty;
            }
          in
          (tmp, [ cast_stmt ])
        else (oir_dst, [])
      in
      let call_stmt =
        if is_void then
          let void_tmp = fresh_var "Sy_void_apply" (void_ty ()) in
          {
            id = fresh_global_id ();
            node =
              Oir.OR_Call
                {
                  dst = void_tmp;
                  target = Direct_fn_ptr { ptr = accum_ptr };
                  args = call_args;
                };
            ty = void_ty ();
          }
        else
          {
            id = fresh_global_id ();
            node =
              Oir.OR_Call
                {
                  dst = call_dst;
                  target = Direct_fn_ptr { ptr = accum_ptr };
                  args = call_args;
                };
            ty = call_dst.ty;
          }
      in
      (ctx, ((load_accum_stmt :: cast_stmts) @ [ call_stmt ]) @ extra_cast_stmt)
  | Cir.CR_Call { dst; target; args } ->
      let ctx, dst' = lower_var ctx dst in
      let ctx, target' = lower_call_target ctx target in
      let ctx, args' =
        List.fold_left_map (fun ctx a -> lower_operand ctx a) ctx args
      in
      ( ctx,
        [
          {
            id = fresh_global_id ();
            node = Oir.OR_Call { dst = dst'; target = target'; args = args' };
            ty = lower_ty stmt.ty;
          };
        ] )
  | Cir.CR_Store_global { global; value } ->
      let ctx, value' = lower_operand ctx value in
      ( ctx,
        [
          {
            id = fresh_global_id ();
            node = Oir.OR_Store_global { global; value = value' };
            ty = lower_ty stmt.ty;
          };
        ] )
  | Cir.CR_Nop ->
      ( ctx,
        [
          { id = fresh_global_id (); node = Oir.OR_Nop; ty = lower_ty stmt.ty };
        ] )

let block_of_cir (ctx : ctx) (block : Cir.block) : ctx * Oir.block =
  let fresh_id =
    match IntMap.find_opt block.id ctx.block_ids with
    | Some id -> id
    | None ->
        failwith
          ("block_of_cir: block not pre-registered: " ^ string_of_int block.id)
  in
  let nop_stmt () : Oir.statement =
    { id = fresh_global_id (); node = Oir.OR_Nop; ty = void_ty () }
  in
  let ctx, oir_groups =
    List.fold_left_map
      (fun ctx stmt -> statement_of_cir ctx stmt)
      ctx block.statements
  in
  let statements =
    List.concat_map
      (fun (group : Oir.statement list) ->
        if List.length group > 1 then group @ [ nop_stmt () ] else group)
      oir_groups
  in
  let ctx, terminator = lower_terminator ctx block.terminator in
  ( ctx,
    {
      id = fresh_id;
      label_id = block.label_id;
      statements;
      terminator;
      pred_blocks = [];
      succ_blocks = [];
    } )

let function_of_cir (ctx : ctx) (fn : Cir.function_cir) : ctx * Oir.function_oir
    =
  (* Reset per-function state: variables and blocks are scoped to one
     function *)
  let ctx = { ctx with var_ids = IntMap.empty; block_ids = IntMap.empty } in
  (* Initialize with params first, then locals, so subsequent references
     resolve *)
  let ctx, params =
    List.fold_left_map (fun ctx p -> lower_var ctx p) ctx fn.params
  in
  let ctx, locals =
    List.fold_left_map (fun ctx l -> lower_var ctx l) ctx fn.locals
  in
  (* Pre-register all block IDs so terminators can reference blocks not yet
     lowered *)
  let ctx =
    List.fold_left
      (fun ctx (b : Cir.block) ->
        let fresh_id = fresh_global_id () in
        { ctx with block_ids = IntMap.add b.id fresh_id ctx.block_ids })
      ctx fn.blocks
  in
  (* Lower all blocks (fn.blocks includes entry_block; lower each once) *)
  let ctx, blocks =
    List.fold_left_map (fun ctx b -> block_of_cir ctx b) ctx fn.blocks
  in
  let entry_block =
    match
      List.filter
        (fun (b : Oir.block) -> b.label_id = fn.entry_block.label_id)
        blocks
    with
    | b :: _ -> b
    | [] -> failwith "function_of_cir: entry block not found in fn.blocks"
  in
  ( ctx,
    {
      id = fresh_global_id ();
      name = fn.name;
      params;
      locals;
      entry_block;
      blocks;
      return_ty = lower_ty fn.return_ty;
      visibility = lower_visibility fn.visibility;
    } )

let lower_ffi_external_function (ffi : Cir.ffi_external_function) :
    Oir.ffi_external_function =
  {
    name = ffi.name;
    syli_name = ffi.syli_name;
    ret_ty = lower_ty ffi.ret_ty;
    params = List.map lower_ty ffi.params;
    calling_convention = ffi.calling_convention;
  }

let lower (ctx : Pipeline_types.cir_mono_ctx) : Pipeline_types.oir_ctx =
  let prog : Cir.module_cir = ctx.module_cir in
  let graph = ctx.closure_graph in
  tmp_counter := 0;
  let lowering_ctx : ctx =
    {
      closure_graph = graph;
      trampolines = StringMap.empty;
      var_ids = IntMap.empty;
      block_ids = IntMap.empty;
    }
  in
  (* Lower original functions, threading ctx to collect generated trampolines *)
  let lowering_ctx, oir_functions =
    List.fold_left_map
      (fun ctx fn -> function_of_cir ctx fn)
      lowering_ctx prog.functions
  in
  let oir_generated_functions =
    StringMap.bindings lowering_ctx.trampolines |> List.map snd
  in
  let lowering_ctx, oir_global_values =
    List.fold_left_map
      (fun ctx (gv : Cir.global_value) ->
        let ctx, init_fn = function_of_cir ctx gv.init_fn in
        ( ctx,
          {
            name = gv.name;
            init_fn;
            value = lower_constant gv.value;
            ty = lower_ty gv.ty;
            visibility = lower_visibility gv.visibility;
          } ))
      lowering_ctx prog.global_values
  in
  let oir_prog : Oir.module_oir =
    {
      name = prog.name;
      type_defs = List.map (fun (n, ty) -> (n, lower_ty ty)) prog.type_defs;
      functions = oir_functions;
      global_values = oir_global_values;
      ffi_external_functions =
        List.map lower_ffi_external_function prog.ffi_external_functions;
    }
  in
  {
    Pipeline_types.module_oir = oir_prog;
    apply_gen_functions = oir_generated_functions;
  }
