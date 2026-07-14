open Rir

let rec string_of_ir_type = function
  | RR_I64 -> "i64"
  | RR_I32 -> "i32"
  | RR_I16 -> "i16"
  | RR_I8 -> "i8"
  | RR_U64 -> "u64"
  | RR_U32 -> "u32"
  | RR_U16 -> "u16"
  | RR_U8 -> "u8"
  | RR_Bool -> "bool"
  | RR_Float -> "f32"
  | RR_Double -> "f64"
  | RR_Ptr inner -> Printf.sprintf "*%s" (string_of_ir_type inner)
  | RR_Void -> "void"
  | RR_Arrow (param_tys, ret_ty) ->
      let params_str =
        param_tys |> List.map string_of_ir_type |> String.concat ", "
      in
      Printf.sprintf "(%s -> %s)" params_str (string_of_ir_type ret_ty)

let string_of_ty (t : ty) : string = string_of_ir_type t.ty

let string_of_visibility = function
  | Cir.CR_Public -> "public"
  | Cir.CR_Private -> "private"

let var_to_string (v : var) : string =
  Printf.sprintf "%%%s:%s" v.fullname (string_of_ty v.ty)

let operand_to_string (op : operand) : string =
  match op with
  | RR_OConstant (c, ty) ->
      let const_str =
        match c with
        | RR_IntLit s -> s
        | RR_FloatLit s -> s
        | RR_BoolLit s -> s
        | RR_StringLit s -> Printf.sprintf "\"%s\"" s
        | RR_CharLit s -> Printf.sprintf "'%s'" s
        | RR_Null -> "null"
      in
      Printf.sprintf "%s:%s" const_str (string_of_ty ty)
  | RR_OVar v -> var_to_string v

let string_of_binop = function
  | Cir.CR_Add -> "+"
  | Cir.CR_Sub -> "-"
  | Cir.CR_Mul -> "*"
  | Cir.CR_Div -> "/"
  | Cir.CR_Mod -> "%"
  | Cir.CR_Eq -> "=="
  | Cir.CR_Ne -> "!="
  | Cir.CR_Lt -> "<"
  | Cir.CR_Le -> "<="
  | Cir.CR_Gt -> ">"
  | Cir.CR_Ge -> ">="
  | Cir.CR_BitAnd -> "&"
  | Cir.CR_BitOr -> "|"
  | Cir.CR_BitXor -> "^"
  | Cir.CR_Shl -> "<<"
  | Cir.CR_Shr -> ">>"
  | Cir.CR_And -> "&&"
  | Cir.CR_Or -> "||"

let string_of_unop = function
  | Cir.CR_Neg -> "-"
  | Cir.CR_Not -> "!"
  | Cir.CR_BitNot -> "~"

let string_of_rvalue (rv : rvalue) : string =
  match rv.node with
  | RR_BinOp { op; lhs; rhs } ->
      Printf.sprintf "%s %s %s" (operand_to_string lhs) (string_of_binop op)
        (operand_to_string rhs)
  | RR_UnOp { op; operand } ->
      Printf.sprintf "%s%s" (string_of_unop op) (operand_to_string operand)
  | RR_Runtime_call { fn_name; args; ret_ty } ->
      let args_str = args |> List.map operand_to_string |> String.concat ", " in
      let ret_str =
        match ret_ty with Some t -> string_of_ty t | None -> "void"
      in
      Printf.sprintf "#runtime_call %s(%s):%s"
        (runtime_op_name_to_string fn_name)
        args_str ret_str
  | RR_Object_load { obj; field_idx; value_ty } ->
      Printf.sprintf "obj_get(%s, %s):%s" (operand_to_string obj)
        (operand_to_string field_idx)
        (string_of_ty value_ty)
  | RR_Cast { src; to_ty } ->
      Printf.sprintf "cast(%s as %s)" (operand_to_string src)
        (string_of_ty to_ty)
  | RR_Addr_fn { fn } -> Printf.sprintf "addr_fn(%s)" fn

let string_of_call_target = function
  | Direct name -> Printf.sprintf "#call_direct %s" name
  | Indirect v -> Printf.sprintf "#call_indirect %s" (var_to_string v)

let string_of_statement (stmt : statement) : string =
  match stmt.node with
  | RR_Assign { dst; rvalue } ->
      Printf.sprintf "  %s = %s" (var_to_string dst) (string_of_rvalue rvalue)
  | RR_Call { dst; target; args } ->
      let args_str = args |> List.map operand_to_string |> String.concat ", " in
      Printf.sprintf "  %s = %s (%s)" (var_to_string dst)
        (string_of_call_target target)
        args_str
  | RR_Runtime_call { dst; call } ->
      let args_str =
        call.args |> List.map operand_to_string |> String.concat ", "
      in
      Printf.sprintf "  %s = #runtime_call %s(%s)" (var_to_string dst)
        (runtime_op_name_to_string call.fn_name)
        args_str
  | RR_Object_store { obj; field_idx; value; value_ty } ->
      Printf.sprintf "  obj_set(%s, %s, %s):%s" (operand_to_string obj)
        (operand_to_string field_idx)
        (operand_to_string value) (string_of_ty value_ty)
  | RR_Store_global { global; value } ->
      Printf.sprintf "  global %s = %s" global (operand_to_string value)
  | RR_Move { dst; src } ->
      Printf.sprintf "  %s = move(%s)" (var_to_string dst)
        (operand_to_string src)
  | RR_Nop -> ""

let string_of_terminator (term : terminator) : string =
  match term.node with
  | RR_Goto id -> Printf.sprintf "  goto bb%d" id
  | RR_Switch { scrutinee; cases; default_block } ->
      let cases_str =
        cases
        |> List.map (fun (c : switch_case_node) ->
            Printf.sprintf "%d -> bb%d" c.value c.target_block)
        |> String.concat ", "
      in
      let default_str =
        match default_block with
        | Some id -> Printf.sprintf ", default -> bb%d" id
        | None -> ""
      in
      Printf.sprintf "  switch %s [%s%s]" (var_to_string scrutinee) cases_str
        default_str
  | RR_CondBr { cond; then_block; else_block } ->
      Printf.sprintf "  cond_br %s, bb%d, bb%d" (var_to_string cond) then_block
        else_block
  | RR_Return None -> "  return"
  | RR_Return (Some op) -> Printf.sprintf "  return %s" (operand_to_string op)

let string_of_block (b : block) : string =
  let stmts_str =
    b.statements |> List.map string_of_statement |> String.concat "\n"
  in
  Printf.sprintf "bb%d:\n%s\n%s" b.label_id stmts_str
    (string_of_terminator b.terminator)

let string_of_function (fn : function_rir) : string =
  let params_str = fn.params |> List.map var_to_string |> String.concat ", " in
  let blocks_str =
    fn.blocks |> List.map string_of_block |> String.concat "\n\n"
  in
  Printf.sprintf "%s fn %s(%s) -> %s:\n  entry: bb%d\n\n%s\nend\n"
    (string_of_visibility fn.visibility)
    fn.name params_str
    (string_of_ty fn.return_ty)
    fn.entry_block.label_id blocks_str

let string_of_ffi_external_function (ffi : ffi_external_function) : string =
  let params_str = ffi.params |> List.map string_of_ty |> String.concat ", " in
  Printf.sprintf "extern fn %s(%s) -> %s" ffi.syli_name params_str
    (string_of_ty ffi.ret_ty)

let string_of_global_value (gv : global_value) : string =
  Printf.sprintf "%s %s = %s : %s"
    (string_of_visibility gv.visibility)
    gv.name
    (match gv.value with
    | RR_IntLit s -> s
    | RR_FloatLit s -> s
    | RR_BoolLit s -> s
    | RR_StringLit s -> Printf.sprintf "\"%s\"" s
    | RR_CharLit s -> Printf.sprintf "'%s'" s
    | RR_Null -> "null")
    (string_of_ty gv.ty)

let string_of_program (prog : program_rir) : string =
  let functions_str =
    prog.functions |> List.map string_of_function |> String.concat "\n\n"
  in
  let ffi_str =
    prog.ffi_external_functions
    |> List.map string_of_ffi_external_function
    |> String.concat "\n"
  in
  let globals_str =
    prog.global_values |> List.map string_of_global_value |> String.concat "\n"
  in
  let type_defs_str =
    prog.type_defs
    |> List.map (fun (name, t) ->
        Printf.sprintf "type %s = %s" name (string_of_ty t))
    |> String.concat "\n"
  in
  Printf.sprintf
    "module %s :\n\
     type_defs:\n\
     %s\n\
     ffi_external_functions:\n\
     %s\n\
     globals:\n\
     %s\n\
     functions:\n\
     %s\n"
    prog.name
    (if type_defs_str = "" then "  (none)" else type_defs_str)
    (if ffi_str = "" then "  (none)" else ffi_str)
    (if globals_str = "" then "  (none)" else globals_str)
    functions_str
