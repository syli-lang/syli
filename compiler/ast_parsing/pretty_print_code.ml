open Ast

let indent n = String.make (n * 2) ' '

let rec string_of_ty (ty : ty) : string =
  match ty.ty_desc with
  | Ty_Constant Ty_Int64 -> "Int64"
  | Ty_Constant Ty_Int32 -> "Int32"
  | Ty_Constant Ty_Int16 -> "Int16"
  | Ty_Constant Ty_Int8 -> "Int8"
  | Ty_Constant Ty_UInt64 -> "UInt64"
  | Ty_Constant Ty_UInt32 -> "UInt32"
  | Ty_Constant Ty_UInt16 -> "UInt16"
  | Ty_Constant Ty_UInt8 -> "UInt8"
  | Ty_Constant Ty_Bool -> "Bool"
  | Ty_Constant Ty_Unit -> "Unit"
  | Ty_Constant Ty_Float -> "Float"
  | Ty_Constant Ty_Double -> "Double"
  | Ty_Constant Ty_StringLit -> "String"
  | Ty_Constant Ty_CharLit -> "Char"
  | Ty_Any -> "_"
  | Ty_Var s -> "'" ^ s
  | Ty_Array ty' -> "Array[" ^ string_of_ty ty' ^ "]"
  | Ty_Tuple tys -> "(" ^ String.concat ", " (List.map string_of_ty tys) ^ ")"
  | Ty_Arrow (params, ret) ->
      "("
      ^ String.concat ", " (List.map string_of_ty params)
      ^ ") -> " ^ string_of_ty ret
  | Ty_Defined { name; args } ->
      let full = name.name in
      if args = [] then full
      else full ^ "[" ^ String.concat ", " (List.map string_of_ty args) ^ "]"

let string_of_unop : unop -> string = function
  | Unop_Logical Not -> "!"
  | Unop_Arithmetic Neg -> "-"
  | Unop_Bitwise BitNot -> "~"

let string_of_binop : binop -> string = function
  | Binop_Arithmetic Add -> "+"
  | Binop_Arithmetic Sub -> "-"
  | Binop_Arithmetic Mul -> "*"
  | Binop_Arithmetic Div -> "/"
  | Binop_Arithmetic Mod -> "%"
  | Binop_Logical And -> "&&"
  | Binop_Logical Or -> "||"
  | Binop_Bitwise BitAnd -> "&"
  | Binop_Bitwise BitOr -> "|"
  | Binop_Bitwise BitXor -> "^"
  | Binop_Bitwise LShift -> "<<"
  | Binop_Bitwise RShift -> ">>"
  | Binop_Comparison Eq -> "=="
  | Binop_Comparison Ne -> "!="
  | Binop_Comparison Lt -> "<"
  | Binop_Comparison Le -> "<="
  | Binop_Comparison Gt -> ">"
  | Binop_Comparison Ge -> ">="

let rec string_of_pattern (p : pattern) : string =
  match p.node with
  | Pat_Unit -> "()"
  | Pat_BoolLit s -> s
  | Pat_IntLit s -> s
  | Pat_CharLit s -> "'" ^ s ^ "'"
  | Pat_FloatLit s -> s
  | Pat_StringLit s -> "\"" ^ String.escaped s ^ "\""
  | Pat_Ident s -> s.name
  | Pat_Wildcard -> "_"
  | Pat_Tuple ps ->
      "(" ^ String.concat ", " (List.map string_of_pattern ps) ^ ")"
  | Pat_Record fields ->
      "{ "
      ^ String.concat ", "
          (List.map
             (fun ((n : ident), p_opt) ->
               match p_opt with
               | None -> n.name
               | Some p' -> n.name ^ " = " ^ string_of_pattern p')
             fields)
      ^ " }"
  | Pat_Constructor (name, None) -> name.name
  | Pat_Constructor (name, Some p') ->
      name.name ^ "(" ^ string_of_pattern p' ^ ")"
  | Pat_Collection (Pat_List ps, _) ->
      "[" ^ String.concat "; " (List.map string_of_pattern ps) ^ "]"
  | Pat_Collection (Pat_Array ps, _) ->
      "[" ^ String.concat ", " (List.map string_of_pattern ps) ^ "]"
  | Pat_Collection (Pat_Set ps, _) ->
      "{." ^ String.concat ", " (List.map string_of_pattern ps) ^ ".}"
  | Pat_Collection (Pat_Map kvs, _) ->
      "{:"
      ^ String.concat ", "
          (List.map
             (fun (k, v) -> string_of_pattern k ^ ": " ^ string_of_pattern v)
             kvs)
      ^ "}"

let string_of_constant (c : constant_desc) : string =
  match c with
  | Const_Unit -> "()"
  | Const_BoolLit s -> s
  | Const_IntLit s -> s
  | Const_FloatLit s -> s
  | Const_CharLit s -> "'" ^ s ^ "'"
  | Const_StringLit s -> "\"" ^ String.escaped s ^ "\""

let string_of_param (p : param) : string =
  let base = string_of_pattern p.pattern in
  match p.param_ty with
  | None -> base
  | Some ty -> base ^ ": " ^ string_of_ty ty

let rec string_of_expr ?(ind = 0) (expr : expr) : string =
  match expr.expr_desc with
  | Exp_Constant c -> string_of_constant c.constant_desc
  | Exp_Ident idr -> idr.name
  | Exp_Tuple exprs ->
      "(" ^ String.concat ", " (List.map (string_of_expr ~ind) exprs) ^ ")"
  | Exp_Record fields ->
      "{ "
      ^ String.concat ", "
          (List.map
             (fun f -> f.field_name ^ ": " ^ string_of_expr ~ind f.field_value)
             fields)
      ^ " }"
  | Exp_Collection (Col_Array exprs) ->
      "[" ^ String.concat ", " (List.map (string_of_expr ~ind) exprs) ^ "]"
  | Exp_Collection (Col_List exprs) ->
      "[" ^ String.concat "; " (List.map (string_of_expr ~ind) exprs) ^ "]"
  | Exp_Collection (Col_Map exprs) ->
      "{:"
      ^ String.concat ", "
          (List.map
             (fun (k, v) ->
               string_of_expr ~ind k ^ ": " ^ string_of_expr ~ind v)
             exprs)
      ^ "}"
  | Exp_Collection (Col_Set exprs) ->
      "{." ^ String.concat ", " (List.map (string_of_expr ~ind) exprs) ^ ".}"
  | Exp_VariantConstructor { name; arg } ->
      let args_str =
        match arg with
        | None -> ""
        | Some e -> "(" ^ string_of_expr ~ind e ^ ")"
      in
      name.name ^ args_str
  | Exp_Lambda { params; body; ret_ty; _ } ->
      let params_str = String.concat ", " (List.map string_of_param params) in
      let ret_str =
        match ret_ty with None -> "" | Some ty -> " -> " ^ string_of_ty ty
      in
      "lambda(" ^ params_str ^ ")" ^ ret_str ^ " {\n"
      ^ indent (ind + 1)
      ^ string_of_expr ~ind:(ind + 1) body
      ^ "\n" ^ indent ind ^ "}"
  | Exp_ArrayCreate { lambda_init = _; element_ty; size } ->
      "array.create(lambda(...), " ^ string_of_ty element_ty ^ ", "
      ^ string_of_expr ~ind size ^ ")"
  | Exp_ArrayLength e -> "array.length(" ^ string_of_expr ~ind e ^ ")"
  | Exp_ArrayGet { arr; idx } ->
      "array.get(" ^ string_of_expr ~ind arr ^ ", " ^ string_of_expr ~ind idx
      ^ ")"
  | Exp_ArraySet { arr; idx; value } ->
      "array.set(" ^ string_of_expr ~ind arr ^ ", " ^ string_of_expr ~ind idx
      ^ ", " ^ string_of_expr ~ind value ^ ")"
  | Exp_UnOp (op, e) -> string_of_unop op ^ string_of_expr ~ind e
  | Exp_BinOp (op, e1, e2) ->
      "(" ^ string_of_expr ~ind e1 ^ " " ^ string_of_binop op ^ " "
      ^ string_of_expr ~ind e2 ^ ")"
  | Exp_Apply { closure_fun; args } ->
      string_of_expr ~ind closure_fun
      ^ "("
      ^ String.concat ", " (List.map (string_of_expr ~ind) args)
      ^ ")"
  | Exp_Let ld ->
      "let "
      ^ string_of_pattern ld.pattern
      ^ (match ld.ty_opt with None -> "" | Some t -> ": " ^ string_of_ty t)
      ^ " = "
      ^ string_of_expr ~ind ld.value
  | Exp_Assign { target; value; _ } ->
      string_of_expr ~ind target ^ " = " ^ string_of_expr ~ind value
  | Exp_If { cond; then_branch; else_branch = None } ->
      "if " ^ string_of_expr ~ind cond ^ " {\n"
      ^ indent (ind + 1)
      ^ string_of_expr ~ind:(ind + 1) then_branch
      ^ "\n" ^ indent ind ^ "}"
  | Exp_If { cond; then_branch; else_branch = Some else_e } ->
      "if " ^ string_of_expr ~ind cond ^ " {\n"
      ^ indent (ind + 1)
      ^ string_of_expr ~ind:(ind + 1) then_branch
      ^ "\n" ^ indent ind ^ "} else {\n"
      ^ indent (ind + 1)
      ^ string_of_expr ~ind:(ind + 1) else_e
      ^ "\n" ^ indent ind ^ "}"
  | Exp_While { cond; body } ->
      "while " ^ string_of_expr ~ind cond ^ " {\n"
      ^ indent (ind + 1)
      ^ string_of_expr ~ind:(ind + 1) body
      ^ "\n" ^ indent ind ^ "}"
  | Exp_ForIn { iter_var; iterable; body } ->
      "for " ^ string_of_pattern iter_var ^ " in "
      ^ string_of_expr ~ind iterable
      ^ " {\n"
      ^ indent (ind + 1)
      ^ string_of_expr ~ind:(ind + 1) body
      ^ "\n" ^ indent ind ^ "}"
  | Exp_Loop body ->
      "loop {\n"
      ^ indent (ind + 1)
      ^ string_of_expr ~ind:(ind + 1) body
      ^ "\n" ^ indent ind ^ "}"
  | Exp_Break None -> "break"
  | Exp_Break (Some e) -> "break " ^ string_of_expr ~ind e
  | Exp_Continue -> "continue"
  | Exp_Return None -> "return"
  | Exp_Return (Some e) -> "return " ^ string_of_expr ~ind e
  | Exp_Seq exprs ->
      "{\n"
      ^ String.concat ";\n"
          (List.map
             (fun e -> indent (ind + 1) ^ string_of_expr ~ind:(ind + 1) e)
             exprs)
      ^ "\n" ^ indent ind ^ "}"
  | Exp_Match (scrutinee, _cases) ->
      "match " ^ string_of_expr ~ind scrutinee ^ " { ... }"
  | Exp_Field { record; field_name } ->
      string_of_expr ~ind record ^ "." ^ field_name.name
  | Exp_Index { collection; index } ->
      string_of_expr ~ind collection ^ "[" ^ string_of_expr ~ind index ^ "]"
