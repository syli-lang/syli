open Cir

let rec string_of_ir_type = function
  | CR_I64 -> "i64"
  | CR_I32 -> "i32"
  | CR_I16 -> "i16"
  | CR_I8 -> "i8"
  | CR_U64 -> "u64"
  | CR_U32 -> "u32"
  | CR_U16 -> "u16"
  | CR_U8 -> "u8"
  | CR_Bool -> "bool"
  | CR_Float -> "f32"
  | CR_Double -> "f64"
  | CR_FnPtr -> "fn_ptr"
  | CR_Obj { named; args } ->
      let name = match named with Some n -> n | None -> "obj" in
      if args = [] then name
      else
        name ^ "<"
        ^ String.concat ", "
            (List.map (fun t -> string_of_ir_type t.ir_type) args)
        ^ ">"
  | CR_Ptr inner -> Printf.sprintf "*%s" (string_of_ir_type inner.ir_type)
  | CR_Void -> "void"
  | CR_GenericTyp { type_var } -> Printf.sprintf "?%d" type_var
  | CR_Arrow (param_tys, ret_ty) ->
      let params_str =
        param_tys
        |> List.map (fun t -> string_of_ir_type t.ir_type)
        |> String.concat ", "
      in
      Printf.sprintf "(%s -> %s)" params_str (string_of_ir_type ret_ty.ir_type)

let string_of_ty (t : ty) : string = string_of_ir_type t.ir_type

let string_of_visibility = function
  | CR_Public -> "public"
  | CR_Private -> "private"

let var_id (v : var) = v.id
let var_ty (v : var) = v.ty

let var_to_string (v : var) : string =
  Printf.sprintf "%%%s:%s" v.name (string_of_ty (var_ty v))

let string_of_operand = function
  | CR_OConstant (c, ty) ->
      let c_str =
        match c with
        | CR_IntLit i -> i
        | CR_FloatLit f -> f ^ "f"
        | CR_BoolLit b -> b
        | CR_StringLit s -> s
        | CR_CharLit c -> "'" ^ c ^ "'"
        | CR_Null -> "null"
      in
      Printf.sprintf "%s:%s" c_str (string_of_ty ty)
  | CR_OVar v -> var_to_string v

let closure_name_of_operand = function CR_OVar _ -> None | _ -> None

let string_of_call_target = function
  | Direct name -> Printf.sprintf "direct %s" name
  | Direct_fn_ptr { ptr } ->
      Printf.sprintf "direct_fn_ptr(%s) " (var_to_string ptr)
  | Apply { closure } -> Printf.sprintf "apply {%s} " (var_to_string closure)

let string_of_binop = function
  | CR_Add -> "+"
  | CR_Sub -> "-"
  | CR_Mul -> "*"
  | CR_Div -> "/"
  | CR_Mod -> "%"
  | CR_Eq -> "=="
  | CR_Ne -> "!="
  | CR_Lt -> "<"
  | CR_Le -> "<="
  | CR_Gt -> ">"
  | CR_Ge -> ">="
  | CR_BitAnd -> "&"
  | CR_BitOr -> "|"
  | CR_BitXor -> "^"
  | CR_Shl -> "<<"
  | CR_Shr -> ">>"
  | CR_And -> "&&"
  | CR_Or -> "||"

let string_of_unop = function CR_Neg -> "-" | CR_Not -> "!" | CR_BitNot -> "~"

let string_of_rvalue (rv : rvalue) : string =
  match rv.node with
  | CR_BinOp { op; lhs; rhs } ->
      Printf.sprintf "%s %s %s" (string_of_operand lhs) (string_of_binop op)
        (string_of_operand rhs)
  | CR_UnOp { op; operand } ->
      Printf.sprintf "%s%s" (string_of_unop op) (string_of_operand operand)
  | CR_Object_get { obj; field_idx; value_ty } ->
      Printf.sprintf "obj_get(%s, %s):%s" (string_of_operand obj)
        (string_of_operand field_idx)
        (string_of_ty value_ty)
  | CR_Object_length { obj } -> Printf.sprintf "len(%s)" (string_of_operand obj)
  | CR_Object_get_tag { obj } ->
      Printf.sprintf "get_tag(%s)" (string_of_operand obj)
  | CR_Cast { src; to_ty } ->
      Printf.sprintf "cast(%s as %s)" (string_of_operand src)
        (string_of_ty to_ty)
  | CR_Move { src } -> Printf.sprintf "move(%s)" (string_of_operand src)
  | CR_Addr_fn { fn } -> Printf.sprintf "addr_fn(%s)" fn

let string_of_object_layout = function
  | CR_Record { field_count; field_types; tag_variant } ->
      let fields_str =
        field_types |> List.map string_of_ty |> String.concat "; "
      in
      Printf.sprintf "record{fields=%d tag=%d [%s]}" field_count tag_variant
        fields_str
  | CR_Array { element_ty; tag_variant } ->
      Printf.sprintf "array{elem=%s tag=%d}" (string_of_ty element_ty)
        tag_variant

let string_of_statement (stmt : statement) : string =
  match stmt.node with
  | CR_Assign { dst; rvalue } ->
      Printf.sprintf "%s = %s" (var_to_string dst) (string_of_rvalue rvalue)
  | CR_Object_set { obj; field_idx; value; value_ty } ->
      Printf.sprintf "obj_set(%s, %s, %s):%s" (var_to_string obj)
        (string_of_operand field_idx)
        (string_of_operand value) (string_of_ty value_ty)
  | CR_Object_create { dst; size; layout; _ } ->
      Printf.sprintf "%s = object_create{size=%s %s}" (var_to_string dst)
        (string_of_operand size)
        (string_of_object_layout layout)
  | CR_Call { dst; target = Apply { closure }; args; _ } ->
      let args_str = String.concat ", " (List.map string_of_operand args) in
      let op_ty = function CR_OConstant (_, ty) -> ty | CR_OVar v -> v.ty in
      let concrete_arrow =
        string_of_ty
          { id = 0; ir_type = CR_Arrow (List.map op_ty args, var_ty dst) }
      in
      let closure_ty_str = string_of_ty (var_ty closure) in
      let as_str =
        if closure_ty_str = concrete_arrow then "" else " as " ^ concrete_arrow
      in
      Printf.sprintf "%s = #call_apply {%s%s}  (%s)" (var_to_string dst)
        (var_to_string closure) as_str args_str
  | CR_Call { dst; target; args; _ } ->
      let dst_str = var_to_string dst ^ " = " in
      let args_str = String.concat ", " (List.map string_of_operand args) in
      Printf.sprintf "%s#call_%s (%s)" dst_str
        (string_of_call_target target)
        args_str
  | CR_Partial_apply { dst; closure; new_args; _ } ->
      let args_str = String.concat ", " (List.map string_of_operand new_args) in
      Printf.sprintf "%s = #partial_apply {%s} (%s)" (var_to_string dst)
        (var_to_string closure) args_str
  | CR_Make_closure { dst; free_vars; captured_args; fn; _ } ->
      let free_vars_str =
        String.concat ", " (List.map var_to_string free_vars)
      in
      let captured_str =
        if captured_args <> [] then
          " captured_args=["
          ^ String.concat ", " (List.map string_of_operand captured_args)
          ^ "]"
        else ""
      in
      Printf.sprintf "%s = #make_closure {%s} (%s) (%s)" (var_to_string dst) fn
        free_vars_str captured_str
  | CR_Store_global { global; value } ->
      Printf.sprintf "store_global %s = %s" global (string_of_operand value)
  | CR_Nop -> "nop"

let string_of_terminator (lookup : int -> int) (term : terminator) : string =
  match term.node with
  | CR_Goto id -> Printf.sprintf "goto bb%d" (lookup id)
  | CR_Switch { scrutinee; cases; default_block } ->
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
  | CR_CondBr { cond; then_block; else_block } ->
      Printf.sprintf "cond_br %s, bb%d, bb%d" (var_to_string cond)
        (lookup then_block) (lookup else_block)
  | CR_Return None -> "return"
  | CR_Return (Some op) -> Printf.sprintf "return %s" (string_of_operand op)

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
    | CR_IntLit i -> i
    | CR_FloatLit f -> f ^ "f"
    | CR_BoolLit b -> b
    | CR_StringLit s -> Printf.sprintf "%S" s
    | CR_CharLit c -> Printf.sprintf "'%s'" c
    | CR_Null -> "null"
  in
  Printf.sprintf "global %s %s : %s = %s%s"
    (string_of_visibility g.visibility)
    g.name (string_of_ty g.ty) value_str init_str

let string_of_function (fn : function_cir) : string =
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

let string_of_program (prog : module_cir) : string =
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
