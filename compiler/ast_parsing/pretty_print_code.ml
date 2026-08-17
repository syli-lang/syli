open Ast
open Types

let indent n = String.make (n * 2) ' '

let rec string_of_ty (ty : ty) : string =
  match ty.ty_desc with
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
  | Ty_Any -> "_"
  | Ty_Var { label; _ } -> "'" ^ label
  | Ty_Array ty' -> "array<" ^ string_of_ty ty' ^ ">"
  | Ty_Ref ty' -> "ref<" ^ string_of_ty ty' ^ ">"
  | Ty_Tuple tys -> "(" ^ String.concat ", " (List.map string_of_ty tys) ^ ")"
  | Ty_Arrow (params, ret) ->
      let params_str = String.concat " * " (List.map string_of_ty params) in
      params_str ^ " -> " ^ string_of_ty ret
  | Ty_Defined { name; args } ->
      let full = name.name in
      if args = [] then full
      else full ^ "<" ^ String.concat ", " (List.map string_of_ty args) ^ ">"

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
  | Binop_Bitwise BitOr -> "lor"
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
  | Pat_Any -> "_"
  | Pat_Tuple { elements } ->
      "(" ^ String.concat ", " (List.map string_of_pattern elements) ^ ")"
  | Pat_Record { fields } ->
      "{ "
      ^ String.concat ", "
          (List.map
             (fun (f : pattern_record_field) ->
               match f.pattern with
               | None -> f.name.name
               | Some p' -> f.name.name ^ " = " ^ string_of_pattern p')
             fields)
      ^ " }"
  | Pat_Constructor { name; pattern = None } -> name.name
  | Pat_Constructor { name; pattern = Some p' } ->
      name.name ^ "(" ^ string_of_pattern p' ^ ")"

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
  | Exp_Tuple { elements } ->
      "(" ^ String.concat ", " (List.map (string_of_expr ~ind) elements) ^ ")"
  | Exp_Record { fields } ->
      "{ "
      ^ String.concat "; "
          (List.map
             (fun (f : record_field) ->
               f.field_name.name ^ " = " ^ string_of_expr ~ind f.field_value)
             fields)
      ^ " }"
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
  | Exp_ArrayCreate { element_ty; size } ->
      "array.create(" ^ string_of_ty element_ty ^ ", "
      ^ string_of_expr ~ind size ^ ")"
  | Exp_ArrayLength { arr } -> "array.length(" ^ string_of_expr ~ind arr ^ ")"
  | Exp_ArrayGet { arr; idx } ->
      "array.get(" ^ string_of_expr ~ind arr ^ ", " ^ string_of_expr ~ind idx
      ^ ")"
  | Exp_ArraySet { arr; idx; value } ->
      "array.set(" ^ string_of_expr ~ind arr ^ ", " ^ string_of_expr ~ind idx
      ^ ", " ^ string_of_expr ~ind value ^ ")"
  | Exp_UnOp { op; value } -> string_of_unop op ^ string_of_expr ~ind value
  | Exp_Ref { value } -> "ref " ^ string_of_expr ~ind value
  | Exp_Deref { value } -> "*" ^ string_of_expr ~ind value
  | Exp_BinOp { op; lvalue; rvalue } ->
      "(" ^ string_of_expr ~ind lvalue ^ " " ^ string_of_binop op ^ " "
      ^ string_of_expr ~ind rvalue ^ ")"
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
  | Exp_Assign { target; value } ->
      string_of_expr ~ind target ^ " = " ^ string_of_expr ~ind value
  | Exp_AssignRef { target; value } ->
      string_of_expr ~ind target ^ " := " ^ string_of_expr ~ind value
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
  | Exp_Loop { expr } ->
      "loop {\n"
      ^ indent (ind + 1)
      ^ string_of_expr ~ind:(ind + 1) expr
      ^ "\n" ^ indent ind ^ "}"
  | Exp_Break { expr_opt = None } -> "break"
  | Exp_Break { expr_opt = Some e } -> "break " ^ string_of_expr ~ind e
  | Exp_Continue -> "continue"
  | Exp_Return { expr_opt = None } -> "return"
  | Exp_Return { expr_opt = Some e } -> "return " ^ string_of_expr ~ind e
  | Exp_Seq { exprs } ->
      "{\n"
      ^ String.concat ";\n"
          (List.map
             (fun e -> indent (ind + 1) ^ string_of_expr ~ind:(ind + 1) e)
             exprs)
      ^ "\n" ^ indent ind ^ "}"
  | Exp_Match { expr = scrutinee; cases } ->
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
  | Exp_Field { record; field_name } ->
      string_of_expr ~ind record ^ "." ^ field_name.name
  | Exp_Index { collection; index } ->
      string_of_expr ~ind collection ^ "[" ^ string_of_expr ~ind index ^ "]"

let string_of_field_decl (f : record_field_decl) : string =
  f.field_name.name ^ ": " ^ string_of_ty f.field_ty

let string_of_constructor_decl (c : variant_constructor_decl) : string =
  match c.arg with
  | None -> c.name.name
  | Some (Constr_ty t) -> c.name.name ^ " of " ^ string_of_ty t
  | Some (Constr_record fields) ->
      c.name.name ^ " of { "
      ^ String.concat "; " (List.map string_of_field_decl fields)
      ^ " }"

let string_of_ty_decl (td : ty_decl) : string =
  match td.def with
  | Tydef_Alias ty -> "type " ^ td.name.name ^ " = " ^ string_of_ty ty
  | Tydef_Record fields ->
      "type " ^ td.name.name ^ " = { "
      ^ String.concat "; " (List.map string_of_field_decl fields)
      ^ " }"
  | Tydef_Variant ctors ->
      "type " ^ td.name.name ^ " = "
      ^ String.concat " | " (List.map string_of_constructor_decl ctors)
  | Tydef_Abstract -> "type " ^ td.name.name

let string_of_signature_item (si : signature_item) : string =
  match si.signature_item_desc with
  | Sig_Value { name; params; value_ty; external_fn } -> (
      let ty_str =
        if params = [] then string_of_ty value_ty
        else
          string_of_ty { value_ty with ty_desc = Ty_Arrow (params, value_ty) }
      in
      match external_fn with
      | None -> "val " ^ name.name ^ " : " ^ ty_str
      | Some ext ->
          "extern " ^ name.name ^ " : " ^ ty_str ^ " = \"" ^ ext.c_name ^ "\"")
  | Sig_Type td -> string_of_ty_decl td
  | Sig_Module ms -> "module " ^ ms.name.name

let string_of_structure_item (item : structure_item) : string =
  match item.structure_item_desc with
  | Str_Let ld ->
      string_of_expr { id = item.id; expr_desc = Exp_Let ld; loc = item.loc }
  | Str_Fun { name; body; _ } -> "fn " ^ name.name ^ " = " ^ string_of_expr body
  | Str_TypeDef td -> string_of_ty_decl td
  | Str_ModuleStruct m -> "module " ^ m.name.name
  | Str_Signature sigs ->
      "signature:\n"
      ^ String.concat "\n"
          (List.map (fun si -> "  " ^ string_of_signature_item si) sigs)
      ^ "\nend"
