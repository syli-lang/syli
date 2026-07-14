open Types
open Helpers

let instruction_to_string indent = function
  | LV_Comment msg -> String.make indent ' ' ^ "; " ^ msg
  | LV_Store (val_, ptr) ->
      Printf.sprintf "%sstore %s, %s" (String.make indent ' ')
        (string_of_typed_operand val_)
        (string_of_typed_operand ptr)
  | LV_Assign (lhs_op, rhs) -> (
      let lhs_str = string_of_operand lhs_op in
      let lhs =
        match lhs_op with LV_Constant _ -> "" | _ -> lhs_str ^ " = "
      in
      let p = String.make indent ' ' in
      match rhs with
      | LV_IBinOp (op, a, b) ->
          Printf.sprintf "%s%s%s %s %s, %s" p lhs (string_of_ibinop op)
            (string_of_lltype (ty_of_operand a))
            (string_of_operand a) (string_of_operand b)
      | LV_FBinOp (op, a, b) ->
          Printf.sprintf "%s%s%s %s %s, %s" p lhs (string_of_fbinop op)
            (string_of_lltype (ty_of_operand a))
            (string_of_operand a) (string_of_operand b)
      | LV_ICmp (cond, a, b) ->
          Printf.sprintf "%s%sicmp %s %s %s, %s" p lhs (string_of_icmp cond)
            (string_of_lltype (ty_of_operand a))
            (string_of_operand a) (string_of_operand b)
      | LV_Alloca ty ->
          Printf.sprintf "%s%salloca %s" p lhs (string_of_lltype ty)
      | LV_Alloca_n { elem_ty; count } ->
          Printf.sprintf "%s%salloca %s, %s" p lhs (string_of_lltype elem_ty)
            (string_of_typed_operand count)
      | LV_Load { ptr; ty } ->
          Printf.sprintf "%s%sload %s, %s" p lhs (string_of_lltype ty)
            (string_of_typed_operand ptr)
      | LV_Call { fn; args; ret_ty } ->
          let args_str =
            String.concat ", " (List.map string_of_typed_operand args)
          in
          if ret_ty = LV_Void then
            Printf.sprintf "%scall %s %s(%s)" p (string_of_lltype ret_ty)
              (string_of_operand fn) args_str
          else
            Printf.sprintf "%s%scall %s %s(%s)" p lhs (string_of_lltype ret_ty)
              (string_of_operand fn) args_str
      | LV_Cast (op, v, ty) ->
          Printf.sprintf "%s%s%s %s to %s" p lhs (string_of_cast_op op)
            (string_of_typed_operand v)
            (string_of_lltype ty)
      | LV_GEP { base; indices; result_ty } ->
          let idxs =
            String.concat ", " (List.map string_of_typed_operand indices)
          in
          Printf.sprintf "%s%sgetelementptr %s, ptr %s, %s" p lhs
            (string_of_lltype result_ty)
            (string_of_operand base) idxs
      | LV_Phi incoming ->
          let ty =
            match incoming with
            | (v, _) :: _ -> ty_of_operand v
            | [] -> failwith "empty phi"
          in
          let inc =
            String.concat ", "
              (List.map
                 (fun (v, l) ->
                   Printf.sprintf "[ %s, %%%s ]" (string_of_operand v) l)
                 incoming)
          in
          Printf.sprintf "%s%sphi %s %s" p lhs (string_of_lltype ty) inc
      | LV_Select (c, t, e) ->
          Printf.sprintf "%s%sselect i1 %s, %s, %s" p lhs (string_of_operand c)
            (string_of_typed_operand t)
            (string_of_typed_operand e))

let block_to_string block =
  let buf = Buffer.create 128 in
  Printf.bprintf buf "%s:\n" block.label;
  List.iter
    (fun inst -> Printf.bprintf buf "%s\n" (instruction_to_string 2 inst))
    block.instructions;
  Printf.bprintf buf "  %s\n" (string_of_terminator block.terminator);
  Buffer.contents buf

let func_to_string (f : func) =
  let buf = Buffer.create 512 in
  let params_str =
    String.concat ", "
      (List.map
         (fun (ty, name) -> Printf.sprintf "%s %%%s" (string_of_lltype ty) name)
         f.params)
  in
  Printf.bprintf buf "define %s @%s(%s) {\n"
    (string_of_lltype f.ret_type)
    f.name params_str;
  List.iter
    (fun block -> Printf.bprintf buf "%s" (block_to_string block))
    f.blocks;
  Printf.bprintf buf "}\n";
  Buffer.contents buf

let module_to_string (m : module_) =
  let buf = Buffer.create 1024 in
  (match m.target_triple with
  | Some t -> Printf.bprintf buf "target triple = \"%s\"\n" t
  | None -> ());
  if m.target_triple <> None then Printf.bprintf buf "\n";
  List.iter
    (fun (name, ty) ->
      Printf.bprintf buf "%%%s = type %s\n" name (string_of_lltype ty))
    m.type_defs;
  if m.type_defs <> [] then Printf.bprintf buf "\n";
  List.iter
    (fun (name, ty) ->
      match ty with
      | LV_Func (args, ret) ->
          let args_str = String.concat ", " (List.map string_of_lltype args) in
          Printf.bprintf buf "declare %s @%s(%s)\n" (string_of_lltype ret) name
            args_str
      | _ -> Printf.bprintf buf "declare %s @%s\n" (string_of_lltype ty) name)
    m.declarations;
  if m.declarations <> [] then Printf.bprintf buf "\n";
  List.iter
    (fun (g : global_var) ->
      let init_str =
        match g.g_init with
        | Some c -> string_of_typed_operand (LV_Constant (c, g.g_type))
        | None ->
            string_of_typed_operand (LV_Constant (LV_ZeroInitializer, g.g_type))
      in
      Printf.bprintf buf "@%s = global %s\n" g.g_name init_str)
    m.globals;
  if m.globals <> [] then Printf.bprintf buf "\n";
  List.iter (fun f -> Printf.bprintf buf "%s\n" (func_to_string f)) m.functions;
  Buffer.contents buf
