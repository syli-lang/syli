open Oir

let rec string_of_ir_type = function
  | OR_I64 -> "i64"
  | OR_I32 -> "i32"
  | OR_I16 -> "i16"
  | OR_I8 -> "i8"
  | OR_U64 -> "u64"
  | OR_U32 -> "u32"
  | OR_U16 -> "u16"
  | OR_U8 -> "u8"
  | OR_Bool -> "bool"
  | OR_Float -> "f32"
  | OR_Double -> "f64"
  | OR_FnPtr -> "fn_ptr"
  | OR_Obj { named; args } ->
      let name = match named with Some n -> n | None -> "obj" in
      if args = [] then name
      else
        name ^ "<"
        ^ String.concat ", "
            (List.map (fun t -> string_of_ir_type t.ir_type) args)
        ^ ">"
  | OR_Obj_Ptr inner -> Printf.sprintf "*%s" (string_of_ir_type inner.ir_type)
  | OR_Char -> "char"
  | OR_Str -> "str"
  | OR_Void -> "void"

let string_of_ty (t : ty) : string = string_of_ir_type t.ir_type

let string_of_visibility = function
  | OR_Public -> "public"
  | OR_Private -> "private"

let var_id (v : var) = v.id
let var_ty (v : var) = v.ty

let var_to_string (v : var) : string =
  Printf.sprintf "%%%s:%s" v.name (string_of_ty (var_ty v))

let string_of_operand = function
  | OR_OConstant (c, ty) ->
      let c_str =
        match c with
        | OR_IntLit i -> i
        | OR_FloatLit f -> f ^ "f"
        | OR_BoolLit b -> b
        | OR_StringLit s -> s
        | OR_CharLit c -> "'" ^ c ^ "'"
        | OR_Null -> "null"
      in
      Printf.sprintf "%s:%s" c_str (string_of_ty ty)
  | OR_OVar v -> var_to_string v

let closure_name_of_operand = function OR_OVar _ -> None | _ -> None

let string_of_call_target = function
  | Direct name -> Printf.sprintf "direct %s" name
  | Direct_fn_ptr { ptr } ->
      Printf.sprintf "direct_fn_ptr(%s) " (var_to_string ptr)

let string_of_binop = function
  | OR_Add -> "+"
  | OR_Sub -> "-"
  | OR_Mul -> "*"
  | OR_Div -> "/"
  | OR_Mod -> "%"
  | OR_Eq -> "=="
  | OR_Ne -> "!="
  | OR_Lt -> "<"
  | OR_Le -> "<="
  | OR_Gt -> ">"
  | OR_Ge -> ">="
  | OR_BitAnd -> "&"
  | OR_BitOr -> "|"
  | OR_BitXor -> "^"
  | OR_Shl -> "<<"
  | OR_Shr -> ">>"
  | OR_And -> "&&"
  | OR_Or -> "||"

let string_of_unop = function OR_Neg -> "-" | OR_Not -> "!" | OR_BitNot -> "~"

let string_of_rvalue (rv : rvalue) : string =
  match rv.node with
  | OR_BinOp { op; lhs; rhs } ->
      Printf.sprintf "%s %s %s" (string_of_operand lhs) (string_of_binop op)
        (string_of_operand rhs)
  | OR_UnOp { op; operand } ->
      Printf.sprintf "%s%s" (string_of_unop op) (string_of_operand operand)
  | OR_Object_get { obj; field_idx; value_ty } ->
      Printf.sprintf "obj_get(%s, %s):%s" (string_of_operand obj)
        (string_of_operand field_idx)
        (string_of_ty value_ty)
  | OR_Object_length { obj } -> Printf.sprintf "len(%s)" (string_of_operand obj)
  | OR_Object_get_tag { obj } ->
      Printf.sprintf "get_tag(%s)" (string_of_operand obj)
  | OR_Cast { src; to_ty } ->
      Printf.sprintf "cast(%s as %s)" (string_of_operand src)
        (string_of_ty to_ty)
  | OR_Move { src } -> Printf.sprintf "move(%s)" (string_of_operand src)
  | OR_Addr_fn { fn } -> Printf.sprintf "addr_fn(%s)" fn

let string_of_object_layout = function
  | OR_Record { field_count; field_types; tag_variant } ->
      let fields_str =
        field_types |> List.map string_of_ty |> String.concat "; "
      in
      Printf.sprintf "record{fields=%d tag=%d [%s]}" field_count tag_variant
        fields_str
  | OR_Array { element_ty; tag_variant } ->
      Printf.sprintf "array{elem=%s tag=%d}" (string_of_ty element_ty)
        tag_variant

let string_of_statement (stmt : statement) : string =
  match stmt.node with
  | OR_Assign { dst; rvalue } ->
      Printf.sprintf "%s = %s" (var_to_string dst) (string_of_rvalue rvalue)
  | OR_Object_set { obj; field_idx; value; value_ty } ->
      Printf.sprintf "obj_set(%s, %s, %s):%s" (var_to_string obj)
        (string_of_operand field_idx)
        (string_of_operand value) (string_of_ty value_ty)
  | OR_Object_create { dst; size; layout; _ } ->
      Printf.sprintf "%s = object_create{size=%s %s}" (var_to_string dst)
        (string_of_operand size)
        (string_of_object_layout layout)
  | OR_Call { dst; target; args; _ } ->
      let dst_str = var_to_string dst ^ " = " in
      let args_str = String.concat ", " (List.map string_of_operand args) in
      Printf.sprintf "%s#call_%s (%s)" dst_str
        (string_of_call_target target)
        args_str
  | OR_Store_global { global; value } ->
      Printf.sprintf "store_global %s = %s" global (string_of_operand value)
  | OR_RC_op { op; obj } ->
      let op_str =
        match op with
        | OR_RC_incr -> "rc_incr"
        | OR_RC_decr -> "rc_decr"
        | OR_RC_check_release -> "rc_check_release"
        | OR_RC_check_drop -> "rc_check_drop"
        | OR_RC_check_lost_cyclic_release -> "rc_check_lost_cyclic_release"
        | OR_RC_check_lost_cyclic_drop -> "rc_check_lost_cyclic_drop"
      in
      Printf.sprintf "%s(%s)" op_str (var_to_string obj)
  | OR_GC_cycle -> "gc_cycle"
  | OR_Nop -> ""

let string_of_terminator (lookup : int -> int) (term : terminator) : string =
  match term.node with
  | OR_Goto id -> Printf.sprintf "goto bb%d" (lookup id)
  | OR_Switch { scrutinee; cases; default_block } ->
      let cases_str =
        String.concat ", "
          (List.map
             (fun (c : switch_case_node) ->
               Printf.sprintf "%d: bb%d" c.value (lookup c.target_block))
             cases)
      in
      let default_str =
        match default_block with
        | Some id -> Printf.sprintf " default: bb%d" (lookup id)
        | None -> ""
      in
      Printf.sprintf "switch %s [%s%s]" (var_to_string scrutinee) cases_str
        default_str
  | OR_CondBr { cond; then_block; else_block } ->
      Printf.sprintf "cond_br %s, bb%d, bb%d" (var_to_string cond)
        (lookup then_block) (lookup else_block)
  | OR_Return None -> "return"
  | OR_Return (Some op) -> Printf.sprintf "return %s" (string_of_operand op)

let string_of_block (lookup : int -> int) (b : block) : string =
  let stmts = List.map (fun s -> "    " ^ string_of_statement s) b.statements in
  let term = "    " ^ string_of_terminator lookup b.terminator in
  Printf.sprintf "  bb%d:\n%s\n%s" b.label_id (String.concat "\n" stmts) term

let string_of_type_def ((name, ty) : string * ty) : string =
  Printf.sprintf "type %s = %s" name (string_of_ty ty)

let string_of_ffi_external_function (fn : ffi_external_function) : string =
  let params_str = fn.params |> List.map string_of_ty |> String.concat ", " in
  let cc_str =
    match fn.calling_convention with
    | Some cc -> Printf.sprintf " cc=%s" cc
    | None -> ""
  in
  Printf.sprintf "extern fn %s(%s) -> %s%s" fn.name params_str
    (string_of_ty fn.ret_ty) cc_str

let string_of_global_value (g : global_value) : string =
  let init_str = Printf.sprintf " init=%s" g.init_fn.name in
  let value_str =
    match g.value with
    | OR_IntLit i -> i
    | OR_FloatLit f -> f ^ "f"
    | OR_BoolLit b -> b
    | OR_StringLit s -> Printf.sprintf "%S" s
    | OR_CharLit c -> Printf.sprintf "'%s'" c
    | OR_Null -> "null"
  in
  Printf.sprintf "global %s %s : %s = %s%s"
    (string_of_visibility g.visibility)
    g.name (string_of_ty g.ty) value_str init_str

let string_of_function (fn : function_oir) : string =
  let params_str = String.concat ", " (List.map var_to_string fn.params) in
  let block_labels = Hashtbl.create 16 in
  List.iter
    (fun (b : block) -> Hashtbl.add block_labels b.id b.label_id)
    fn.blocks;
  let lookup id = Hashtbl.find block_labels id in
  let blocks_str =
    String.concat "\n\n" (List.map (string_of_block lookup) fn.blocks)
  in
  Printf.sprintf "%s fn %s(%s) -> %s:\n  entry: bb%d\n\n%s\nend"
    (string_of_visibility fn.visibility)
    fn.name params_str
    (string_of_ty fn.return_ty)
    (lookup fn.entry_block.id) blocks_str

let string_of_program (prog : module_oir) : string =
  let all_functions = prog.functions in
  let sections =
    [
      ( "type_defs",
        prog.type_defs |> List.map string_of_type_def |> String.concat "\n" );
      ( "ffi_external_functions",
        prog.ffi_external_functions
        |> List.map string_of_ffi_external_function
        |> String.concat "\n" );
      ( "globals",
        prog.global_values
        |> List.map string_of_global_value
        |> String.concat "\n" );
      ( "functions",
        all_functions |> List.map string_of_function |> String.concat "\n\n" );
    ]
    |> List.filter (fun (_, body) -> body <> "")
  in
  let render_section (title, body) = Printf.sprintf "%s:\n%s\n" title body in
  if sections = [] then Printf.sprintf "module %s {\n}" prog.name
  else
    Printf.sprintf "module %s :\n%s\nend" prog.name
      (sections |> List.map render_section |> String.concat "\n\n")
