(** Liveness analysis for reference-typed OIR variables *)

open Syli_ir.Oir
open Syli_common
module Cfg = Syli_ir.Oir_cfg

type live_info_stmt = { live_before : IntSet.t; live_after : IntSet.t }

type live_info_block = {
  live_entry : IntSet.t;
  live_at_end : IntSet.t;
  dead_entry : IntSet.t;
}

type t = { stmts : live_info_stmt IntMap.t; blocks : live_info_block IntMap.t }

(* ── Helpers ──────────────────────────────────────────────────── *)

let is_ref_ir_type (t : ir_type) : bool =
  match t with OR_Obj _ | OR_Obj_Ptr -> true | _ -> false

let is_ref_ty (t : ty) : bool = is_ref_ir_type t.ir_type

let vars_of_operand (op : operand) : IntSet.t =
  match op with
  | OR_OVar v when is_ref_ty v.ty -> IntSet.singleton v.id
  | _ -> IntSet.empty

let vars_of_rvalue (rv : rvalue) : IntSet.t =
  match rv.node with
  | OR_BinOp { lhs; rhs } ->
      IntSet.union (vars_of_operand lhs) (vars_of_operand rhs)
  | OR_UnOp { operand } -> vars_of_operand operand
  | OR_Object_get { obj; field_idx } ->
      IntSet.union (vars_of_operand obj) (vars_of_operand field_idx)
  | OR_Object_length { obj } -> vars_of_operand obj
  | OR_Object_get_tag { obj } -> vars_of_operand obj
  | OR_Cast { src } -> vars_of_operand src
  | OR_Move { src } -> vars_of_operand src
  | OR_Addr_fn _ -> IntSet.empty

let ref_use_of_stmt (stmt : statement) : IntSet.t =
  match stmt.node with
  | OR_Assign { rvalue; _ } -> vars_of_rvalue rvalue
  | OR_Object_set { obj; field_idx; value; _ } ->
      IntSet.union
        (vars_of_operand (OR_OVar obj))
        (IntSet.union (vars_of_operand field_idx) (vars_of_operand value))
  | OR_Object_create { size; _ } -> vars_of_operand size
  | OR_Call { args; _ } ->
      List.fold_left
        (fun s a -> IntSet.union s (vars_of_operand a.operand))
        IntSet.empty args
  | OR_Release { obj } -> IntSet.singleton obj.id
  | OR_Store_global { value } -> vars_of_operand value
  | OR_Nop | OR_GC_cycle -> IntSet.empty

let ref_def_of_stmt (stmt : statement) : IntSet.t =
  match stmt.node with
  | OR_Assign { dst; _ } when is_ref_ty dst.ty -> IntSet.singleton dst.id
  | OR_Object_create { dst; _ } when is_ref_ty dst.ty -> IntSet.singleton dst.id
  | OR_Call { dst; _ } when is_ref_ty dst.ty -> IntSet.singleton dst.id
  | _ -> IntSet.empty

let terminator_uses (term : terminator) : IntSet.t =
  match term.node with
  | OR_Return { operand = Some op; _ } -> vars_of_operand op
  | OR_CondBr { cond; _ } -> vars_of_operand (OR_OVar cond)
  | OR_Switch { scrutinee; _ } -> vars_of_operand (OR_OVar scrutinee)
  | OR_Return { operand = None; _ } | OR_Goto _ -> IntSet.empty

(* ── Main analysis ────────────────────────────────────────────── *)

let analyze (fn : function_oir) : t =
  let cfg = Cfg.build_cfg fn.blocks in
  let block_map = Cfg.build_block_map fn.blocks in
  (* Initialise every statement's live info *)
  let empty_info = { live_before = IntSet.empty; live_after = IntSet.empty } in
  let result =
    List.fold_left
      (fun map (b : block) ->
        List.fold_left
          (fun map (stmt : statement) -> IntMap.add stmt.id empty_info map)
          map b.statements)
      IntMap.empty fn.blocks
  in
  (* Process blocks in reverse RPO so successors come before predecessors *)
  let order = Cfg.compute_rpo cfg fn.entry_block.id |> List.rev in
  let result, blocks =
    List.fold_left
      (fun (result, blocks) block_id ->
        let b =
          try IntMap.find block_id block_map
          with Not_found -> failwith "liveness: block not found"
        in
        let stmts = b.statements in
        (* live_after of the last statement = union of successor live_entry *)
        let succ_ids = Cfg.get_succ cfg block_id in
        let succ_live =
          List.fold_left
            (fun live sid ->
              match IntMap.find_opt sid blocks with
              | Some info -> IntSet.union live info.live_entry
              | None -> live)
            IntSet.empty succ_ids
        in
        let live_at_end =
          IntSet.union succ_live (terminator_uses b.terminator)
        in
        (* Walk statements backward, threading the map *)
        let live_at_first, result =
          List.fold_left
            (fun (live, map) (stmt : statement) ->
              let uses = ref_use_of_stmt stmt in
              let defs = ref_def_of_stmt stmt in
              let live_before = IntSet.union uses (IntSet.diff live defs) in
              let map =
                IntMap.add stmt.id { live_before; live_after = live } map
              in
              (live_before, map))
            (live_at_end, result) (List.rev stmts)
        in
        (* liveness at block entry *)
        let live_entry =
          if block_id = fn.entry_block.id then
            List.fold_left
              (fun s (p : var) ->
                if is_ref_ty p.ty then IntSet.add p.id s else s)
              live_at_first fn.params
          else live_at_first
        in
        ( result,
          IntMap.add block_id
            { live_entry; live_at_end; dead_entry = IntSet.empty }
            blocks ))
      (result, IntMap.empty) order
  in
  (* Compute dead_entry: separate pass after all live_entry values are final *)
  let blocks =
    List.fold_left
      (fun blocks (block : block) ->
        match IntMap.find_opt block.id blocks with
        | Some info ->
            let dead_entry =
              if block.id = fn.entry_block.id then
                match block.statements with
                | first :: _ -> (
                    (*The first instruction reveals the liveness*)
                    match IntMap.find_opt first.id result with
                    | Some i -> IntSet.diff info.live_entry i.live_before
                    | None -> info.live_entry)
                | [] -> info.live_entry
              else
                let pred_ids = Cfg.get_pred cfg block.id in
                let dead_at_edge p_id =
                  match IntMap.find_opt p_id blocks with
                  | Some p_info ->
                      IntSet.diff p_info.live_at_end info.live_entry
                  | None -> IntSet.empty
                in
                match pred_ids with
                | [] -> IntSet.empty
                | p :: rest ->
                    let init = dead_at_edge p in
                    List.fold_left
                      (fun acc p -> IntSet.inter acc (dead_at_edge p))
                      init rest
            in
            IntMap.add block.id
              {
                live_entry = info.live_entry;
                live_at_end = info.live_at_end;
                dead_entry;
              }
              blocks
        | None -> blocks)
      blocks fn.blocks
  in
  { stmts = result; blocks }
