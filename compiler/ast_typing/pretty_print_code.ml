open Typed_ast

let indent n = String.make (n * 2) ' '

let rec string_of_ty (t : ty) : string =
  match t.ty_desc with
  | TTy_Constant TTy_Int64 -> "int64"
  | TTy_Constant TTy_Int32 -> "int32"
  | TTy_Constant TTy_Int16 -> "int16"
  | TTy_Constant TTy_Int8 -> "int8"
  | TTy_Constant TTy_UInt64 -> "uint64"
  | TTy_Constant TTy_UInt32 -> "uint32"
  | TTy_Constant TTy_UInt16 -> "uint16"
  | TTy_Constant TTy_UInt8 -> "uint8"
  | TTy_Constant TTy_Bool -> "bool"
  | TTy_Constant TTy_Unit -> "unit"
  | TTy_Constant TTy_Float -> "float"
  | TTy_Constant TTy_Double -> "double"
  | TTy_Constant TTy_StringLit -> "string"
  | TTy_Constant TTy_CharLit -> "char"
  | TTy_Array ty -> "array[" ^ string_of_ty ty ^ "]"
  | TTy_Tuple tys -> "(" ^ String.concat ", " (List.map string_of_ty tys) ^ ")"
  | TTy_Arrow (params, ret) ->
      "("
      ^ String.concat ", " (List.map string_of_ty params)
      ^ ") -> " ^ string_of_ty ret
  | TTy_Var i -> "'" ^ string_of_int i
  | TTy_Defined { name; args } ->
      let base = name.name in
      if args = [] then base
      else base ^ "[" ^ String.concat ", " (List.map string_of_ty args) ^ "]"
  | TTy_Any -> "_"

let string_of_unop : unop -> string = function
  | TUnop_Logical TNot -> "!"
  | TUnop_Arithmetic TNeg -> "-"
  | TUnop_Bitwise TBitNot -> "~"

let string_of_binop : binop -> string = function
  | TBinop_Arithmetic TAdd -> "+"
  | TBinop_Arithmetic TSub -> "-"
  | TBinop_Arithmetic TMul -> "*"
  | TBinop_Arithmetic TDiv -> "/"
  | TBinop_Arithmetic TMod -> "%"
  | TBinop_Logical TAnd -> "&&"
  | TBinop_Logical TOr -> "||"
  | TBinop_Bitwise TBitAnd -> "&"
  | TBinop_Bitwise TBitOr -> "|"
  | TBinop_Bitwise TBitXor -> "^"
  | TBinop_Bitwise TLShift -> "<<"
  | TBinop_Bitwise TRShift -> ">>"
  | TBinop_Comparison TEq -> "=="
  | TBinop_Comparison TNe -> "!="
  | TBinop_Comparison TLt -> "<"
  | TBinop_Comparison TLe -> "<="
  | TBinop_Comparison TGt -> ">"
  | TBinop_Comparison TGe -> ">="

let rec string_of_pattern (p : pattern) : string =
  match p.pattern_desc with
  | TPat_Unit -> "()"
  | TPat_BoolLit b -> b
  | TPat_IntLit n -> n
  | TPat_CharLit c -> "'" ^ c ^ "'"
  | TPat_FloatLit f -> f
  | TPat_StringLit s -> "\"" ^ String.escaped s ^ "\""
  | TPat_Ident s -> s.name
  | TPat_Tuple pats ->
      "(" ^ String.concat ", " (List.map string_of_pattern pats) ^ ")"
  | TPat_Record fields ->
      "{ "
      ^ String.concat ", "
          (List.map
             (fun (n, p_opt) ->
               match p_opt with
               | None -> n
               | Some p' -> n ^ ": " ^ string_of_pattern p')
             fields)
      ^ " }"
  | TPat_Constructor (name, None) -> name
  | TPat_Constructor (name, Some pat) ->
      name ^ "(" ^ string_of_pattern pat ^ ")"
  | TPat_Collection (TPat_List pats, _) ->
      "[" ^ String.concat "; " (List.map string_of_pattern pats) ^ "]"
  | TPat_Collection (TPat_Array pats, _) ->
      "[" ^ String.concat ", " (List.map string_of_pattern pats) ^ "]"
  | TPat_Collection (TPat_Set pats, _) ->
      "{." ^ String.concat ", " (List.map string_of_pattern pats) ^ ".}"
  | TPat_Collection (TPat_Map kvs, _) ->
      "{:"
      ^ String.concat ", "
          (List.map
             (fun (k, v) -> string_of_pattern k ^ ": " ^ string_of_pattern v)
             kvs)
      ^ "}"
  | TPat_Wildcard -> "_"

let string_of_constant (c : constant) : string =
  match c.constant_desc with
  | TConst_Unit -> "()"
  | TConst_BoolLit s -> s
  | TConst_IntLit s -> s
  | TConst_FloatLit s -> s
  | TConst_CharLit s -> "'" ^ s ^ "'"
  | TConst_StringLit s -> "\"" ^ String.escaped s ^ "\""

let rec string_of_expr ?(ind = 0) (expr : expr) : string =
  match expr.expr_desc with
  | TExp_Constant c -> string_of_constant c
  | TExp_Ident idr -> idr.name
  | TExp_Tuple exprs ->
      "(" ^ String.concat ", " (List.map (string_of_expr ~ind) exprs) ^ ")"
  | TExp_Record fields ->
      "{ "
      ^ String.concat ", "
          (List.map
             (fun f ->
               f.field_name.name ^ ": " ^ string_of_expr ~ind f.field_value)
             fields)
      ^ " }"
  | TExp_Collection (TCol_Array exprs) ->
      "[" ^ String.concat ", " (List.map (string_of_expr ~ind) exprs) ^ "]"
  | TExp_Collection (TCol_List exprs) ->
      "[" ^ String.concat "; " (List.map (string_of_expr ~ind) exprs) ^ "]"
  | TExp_Collection (TCol_Map exprs) ->
      "{:"
      ^ String.concat ", "
          (List.map
             (fun (k, v) ->
               string_of_expr ~ind k ^ ": " ^ string_of_expr ~ind v)
             exprs)
      ^ "}"
  | TExp_Collection (TCol_Set exprs) ->
      "{." ^ String.concat ", " (List.map (string_of_expr ~ind) exprs) ^ ".}"
  | TExp_VariantConstructor { name; args = None } -> name.name
  | TExp_VariantConstructor { name; args = Some e } ->
      name.name ^ "(" ^ string_of_expr ~ind e ^ ")"
  | TExp_ArrayCreate _ -> "array.create(...)"
  | TExp_ArrayLength e -> "array.length(" ^ string_of_expr ~ind e ^ ")"
  | TExp_ArrayGet { arr; idx } ->
      "array.get(" ^ string_of_expr ~ind arr ^ ", " ^ string_of_expr ~ind idx
      ^ ")"
  | TExp_ArraySet { arr; idx; value } ->
      "array.set(" ^ string_of_expr ~ind arr ^ ", " ^ string_of_expr ~ind idx
      ^ ", " ^ string_of_expr ~ind value ^ ")"
  | TExp_UnOp (op, e) -> string_of_unop op ^ string_of_expr ~ind e
  | TExp_BinOp (op, e1, e2) ->
      "(" ^ string_of_expr ~ind e1 ^ " " ^ string_of_binop op ^ " "
      ^ string_of_expr ~ind e2 ^ ")"
  | TExp_Lambda (lam : lambda) ->
      let params =
        List.map
          (fun (p : param) ->
            match p.pattern.pattern_desc with
            | TPat_Ident s -> s.name
            | _ -> "_")
          lam.params
      in
      "lambda(" ^ String.concat ", " params ^ ") => "
      ^ string_of_expr ~ind lam.body
  | TExp_Apply { closure_fun; args } ->
      string_of_expr ~ind closure_fun
      ^ "("
      ^ String.concat ", " (List.map (string_of_expr ~ind) args)
      ^ ")"
  | TExp_Let l ->
      let lhs =
        match l.pattern.pattern_desc with TPat_Ident s -> s.name | _ -> "_"
      in
      "let " ^ lhs ^ " = " ^ string_of_expr ~ind l.value
  | TExp_Assign { target; value } ->
      string_of_expr ~ind target ^ " = " ^ string_of_expr ~ind value
  | TExp_If { cond; then_branch; else_branch = None } ->
      "if " ^ string_of_expr ~ind cond ^ " then "
      ^ string_of_expr ~ind then_branch
  | TExp_If { cond; then_branch; else_branch = Some e } ->
      "if " ^ string_of_expr ~ind cond ^ " then "
      ^ string_of_expr ~ind then_branch
      ^ " else " ^ string_of_expr ~ind e
  | TExp_While { cond; body } ->
      "while " ^ string_of_expr ~ind cond ^ " do " ^ string_of_expr ~ind body
  | TExp_ForIn { iter_var; iterable; body } ->
      "for " ^ string_of_pattern iter_var ^ " in "
      ^ string_of_expr ~ind iterable
      ^ " do " ^ string_of_expr ~ind body
  | TExp_Loop body -> "loop " ^ string_of_expr ~ind body
  | TExp_Break None -> "break"
  | TExp_Break (Some e) -> "break " ^ string_of_expr ~ind e
  | TExp_Continue -> "continue"
  | TExp_Return None -> "return"
  | TExp_Return (Some e) -> "return " ^ string_of_expr ~ind e
  | TExp_Seq exprs ->
      "{\n"
      ^ String.concat "\n"
          (List.map
             (fun e -> indent (ind + 1) ^ string_of_expr ~ind:(ind + 1) e)
             exprs)
      ^ "\n" ^ indent ind ^ "}"
  | TExp_Match (scrutinee, _cases) ->
      "match " ^ string_of_expr ~ind scrutinee ^ " { ... }"
  | TExp_Field { record; field_name } ->
      string_of_expr ~ind record ^ "." ^ field_name
  | TExp_Index { collection; index } ->
      string_of_expr ~ind collection ^ "[" ^ string_of_expr ~ind index ^ "]"
