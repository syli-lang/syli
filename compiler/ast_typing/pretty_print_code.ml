open Typed_ast

let indent n = String.make (n * 2) ' '

let rec string_of_ty (t : ty) : string =
  match t.ty_desc with
  | Ty_Constant Ty_Int64 -> "int64"
  | Ty_Constant Ty_Int32 -> "int32"
  | Ty_Constant Ty_Int16 -> "int16"
  | Ty_Constant Ty_Int8 -> "int8"
  | Ty_Constant Ty_UInt64 -> "uint64"
  | Ty_Constant Ty_UInt32 -> "uint32"
  | Ty_Constant Ty_UInt16 -> "uint16"
  | Ty_Constant Ty_UInt8 -> "uint8"
  | Ty_Constant Ty_Bool -> "bool"
  | Ty_Constant Ty_Unit -> "unit"
  | Ty_Constant Ty_Float -> "float"
  | Ty_Constant Ty_Double -> "double"
  | Ty_Constant Ty_StringLit -> "str"
  | Ty_Constant Ty_CharLit -> "char"
  | Ty_Array ty -> "array[" ^ string_of_ty ty ^ "]"
  | Ty_Ref ty -> "ref<" ^ string_of_ty ty ^ ">"
  | Ty_Tuple tys -> "(" ^ String.concat " * " (List.map string_of_ty tys) ^ ")"
  | Ty_Arrow (params, ret) ->
      let params_str = String.concat " -> " (List.map string_of_ty params) in
      params_str ^ " -> " ^ string_of_ty ret
  | Ty_Var { variable = Some i; _ } -> "'" ^ string_of_int i
  | Ty_Var { label; variable = None } -> "'" ^ label
  | Ty_Defined { name; args } ->
      let base = name.name in
      if args = [] then base
      else base ^ "[" ^ String.concat ", " (List.map string_of_ty args) ^ "]"
  | Ty_Any -> "_"

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
  | TBinop_Bitwise TBitOr -> "lor"
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
  | TPat_Any -> "_"
  | TPat_Tuple { elements } ->
      "(" ^ String.concat ", " (List.map string_of_pattern elements) ^ ")"
  | TPat_Record { fields } ->
      "{ "
      ^ String.concat ", "
          (List.map
             (fun (f : pattern_record_field) ->
               match f.pattern with
               | None -> f.name.name
               | Some p' -> f.name.name ^ ": " ^ string_of_pattern p')
             fields)
      ^ " }"
  | TPat_Constructor { ident = name; pattern = None } -> name
  | TPat_Constructor { ident = name; pattern = Some pat } ->
      name ^ "(" ^ string_of_pattern pat ^ ")"

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
  | TExp_Tuple { elements } ->
      "(" ^ String.concat ", " (List.map (string_of_expr ~ind) elements) ^ ")"
  | TExp_Record { fields } ->
      "{ "
      ^ String.concat ", "
          (List.map
             (fun f ->
               f.field_name.name ^ ": " ^ string_of_expr ~ind f.field_value)
             fields)
      ^ " }"
  | TExp_VariantConstructor { name; args = None } -> name.name
  | TExp_VariantConstructor { name; args = Some e } ->
      name.name ^ "(" ^ string_of_expr ~ind e ^ ")"
  | TExp_ArrayCreate _ -> "array.create(...)"
  | TExp_ArrayLength { arr } -> "array.length(" ^ string_of_expr ~ind expr ^ ")"
  | TExp_ArrayGet { arr; idx } ->
      "array.get(" ^ string_of_expr ~ind expr ^ ", " ^ string_of_expr ~ind idx
      ^ ")"
  | TExp_ArraySet { arr; idx; value } ->
      "array.set(" ^ string_of_expr ~ind expr ^ ", " ^ string_of_expr ~ind idx
      ^ ", " ^ string_of_expr ~ind value ^ ")"
  | TExp_UnOp { op; value } -> string_of_unop op ^ string_of_expr ~ind value
  | TExp_Ref { value } -> "ref " ^ string_of_expr ~ind value
  | TExp_Deref { value } -> "*" ^ string_of_expr ~ind value
  | TExp_BinOp { op; lvalue; rvalue } ->
      "(" ^ string_of_expr ~ind lvalue ^ " " ^ string_of_binop op ^ " "
      ^ string_of_expr ~ind rvalue ^ ")"
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
  | TExp_AssignRef { target; value } ->
      string_of_expr ~ind target ^ " := " ^ string_of_expr ~ind value
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
  | TExp_Loop { expr } -> "loop " ^ string_of_expr ~ind expr
  | TExp_Break { expr_opt = None } -> "break"
  | TExp_Break { expr_opt = Some e } -> "break " ^ string_of_expr ~ind e
  | TExp_Continue -> "continue"
  | TExp_Return { expr_opt = None } -> "return"
  | TExp_Return { expr_opt = Some e } -> "return " ^ string_of_expr ~ind e
  | TExp_Seq { exprs } ->
      "{\n"
      ^ String.concat "\n"
          (List.map
             (fun e -> indent (ind + 1) ^ string_of_expr ~ind:(ind + 1) e)
             exprs)
      ^ "\n" ^ indent ind ^ "}"
  | TExp_Match { expr = scrutinee; cases } ->
      let cases_str =
        List.map
          (fun (c : pattern_case) ->
            let guard =
              match c.when_condition with
              | None -> ""
              | Some g -> " when " ^ string_of_expr ~ind g
            in
            indent (ind + 1)
            ^ "| "
            ^ string_of_pattern c.pattern
            ^ guard ^ " -> "
            ^ string_of_expr ~ind:(ind + 1) c.body)
          cases
      in
      "match "
      ^ string_of_expr ~ind scrutinee
      ^ " {\n"
      ^ String.concat "\n" cases_str
      ^ "\n" ^ indent ind ^ "}"
  | TExp_Field { record; field_name; _ } ->
      string_of_expr ~ind record ^ "." ^ field_name
  | TExp_Index { collection; index } ->
      string_of_expr ~ind collection ^ "[" ^ string_of_expr ~ind index ^ "]"
