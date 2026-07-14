open Types
open Helpers

type module_ = Types.module_

type gen_state = {
  next_reg : int;
  blocks : (string, block) Hashtbl.t;
  current_block : string option;
}

type builder = { module_ : module_; state : gen_state }

let init_state () =
  { next_reg = 0; blocks = Hashtbl.create 16; current_block = None }

let create_module ?target_triple ?data_layout:_ ?(source_filename = "") () =
  {
    target_triple;
    type_defs = [];
    declarations = [];
    globals = [];
    functions = [];
    source_filename;
  }

let create_builder module_ = { module_; state = init_state () }

let fresh_reg builder ty =
  let n = builder.state.next_reg in
  let state = { builder.state with next_reg = n + 1 } in
  let op = LV_Local ("t" ^ string_of_int n, ty) in
  ({ builder with state }, op)

let emit builder inst =
  match builder.state.current_block with
  | None -> failwith "No current block"
  | Some label ->
      let block = Hashtbl.find builder.state.blocks label in
      let block = { block with instructions = block.instructions @ [ inst ] } in
      Hashtbl.replace builder.state.blocks label block;
      builder

let set_terminator builder term =
  match builder.state.current_block with
  | None -> failwith "No current block"
  | Some label ->
      let block = Hashtbl.find builder.state.blocks label in
      let block = { block with terminator = term } in
      Hashtbl.replace builder.state.blocks label block;
      builder

let with_block builder label f =
  let block = { label; instructions = []; terminator = LV_Unreachable } in
  Hashtbl.add builder.state.blocks label block;
  let builder =
    { builder with state = { builder.state with current_block = Some label } }
  in
  let builder, result = f builder in
  let builder =
    { builder with state = { builder.state with current_block = None } }
  in
  (builder, result)

(* Instruction builders *)
let build_alloca builder ty =
  let builder, reg = fresh_reg builder LV_Ptr in
  let builder = emit builder (LV_Assign (reg, LV_Alloca ty)) in
  (builder, reg)

let build_alloca_n builder elem_ty count =
  let builder, reg = fresh_reg builder LV_Ptr in
  let builder =
    emit builder (LV_Assign (reg, LV_Alloca_n { elem_ty; count }))
  in
  (builder, reg)

let build_load builder ptr load_ty =
  let builder, reg = fresh_reg builder load_ty in
  let builder = emit builder (LV_Assign (reg, LV_Load { ptr; ty = load_ty })) in
  (builder, reg)

let build_store builder val_ ptr =
  let builder = emit builder (LV_Store (val_, ptr)) in
  (builder, ())

let build_ibinop builder op a b =
  let ty = ty_of_operand a in
  let builder, reg = fresh_reg builder ty in
  let builder = emit builder (LV_Assign (reg, LV_IBinOp (op, a, b))) in
  (builder, reg)

let build_fbinop builder op a b =
  let ty = ty_of_operand a in
  let builder, reg = fresh_reg builder ty in
  let builder = emit builder (LV_Assign (reg, LV_FBinOp (op, a, b))) in
  (builder, reg)

let build_icmp builder cond a b =
  let builder, reg = fresh_reg builder LV_I1 in
  let builder = emit builder (LV_Assign (reg, LV_ICmp (cond, a, b))) in
  (builder, reg)

let build_gep builder base indices result_ty =
  let builder, reg = fresh_reg builder LV_Ptr in
  let builder =
    emit builder (LV_Assign (reg, LV_GEP { base; indices; result_ty }))
  in
  (builder, reg)

let build_call builder func args =
  let ret_ty =
    match ty_of_operand func with
    | LV_Func (_, ret) -> ret
    | _ -> failwith "call expects function type"
  in
  match ret_ty with
  | LV_Void ->
      let builder =
        emit builder
          (LV_Assign
             ( LV_Constant (LV_Null, LV_Void),
               LV_Call { fn = func; args; ret_ty } ))
      in
      (builder, None)
  | _ ->
      let builder, reg = fresh_reg builder ret_ty in
      let builder =
        emit builder (LV_Assign (reg, LV_Call { fn = func; args; ret_ty }))
      in
      (builder, Some reg)

let build_cast builder op v result_ty =
  let builder, reg = fresh_reg builder result_ty in
  let builder = emit builder (LV_Assign (reg, LV_Cast (op, v, result_ty))) in
  (builder, reg)

let build_phi builder ty incoming =
  let builder, reg = fresh_reg builder ty in
  let builder = emit builder (LV_Assign (reg, LV_Phi incoming)) in
  (builder, reg)

let build_select builder cond true_val false_val =
  let ty = ty_of_operand true_val in
  let builder, reg = fresh_reg builder ty in
  let builder =
    emit builder (LV_Assign (reg, LV_Select (cond, true_val, false_val)))
  in
  (builder, reg)

let build_br builder label = set_terminator builder (LV_Br label)

let build_cond_br builder cond true_label false_label =
  set_terminator builder (LV_CondBr (cond, true_label, false_label))

let build_ret builder op = set_terminator builder (LV_Ret (Some op))
let build_ret_void builder = set_terminator builder (LV_Ret None)

let add_comment builder msg =
  match builder.state.current_block with
  | None -> builder
  | Some _ -> emit builder (LV_Comment msg)
