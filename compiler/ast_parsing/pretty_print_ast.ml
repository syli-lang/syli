open Ast

(* -------------------------------------------------------------------------- *)
(* Pretty-printers using Format module *)
(* -------------------------------------------------------------------------- *)

let rec pp_ty fmt (ty : ty) =
  match ty.ty_desc with
  | Ty_Constant Ty_Int64 -> Format.fprintf fmt "int64"
  | Ty_Constant Ty_Int32 -> Format.fprintf fmt "int32"
  | Ty_Constant Ty_Int16 -> Format.fprintf fmt "int16"
  | Ty_Constant Ty_Int8 -> Format.fprintf fmt "int8"
  | Ty_Constant Ty_UInt64 -> Format.fprintf fmt "uint64"
  | Ty_Constant Ty_UInt32 -> Format.fprintf fmt "uint32"
  | Ty_Constant Ty_UInt16 -> Format.fprintf fmt "uint16"
  | Ty_Constant Ty_UInt8 -> Format.fprintf fmt "uint8"
  | Ty_Constant Ty_Bool -> Format.fprintf fmt "bool"
  | Ty_Constant Ty_Unit -> Format.fprintf fmt "unit"
  | Ty_Constant Ty_Float -> Format.fprintf fmt "float"
  | Ty_Constant Ty_Double -> Format.fprintf fmt "double"
  | Ty_Constant Ty_StringLit -> Format.fprintf fmt "str"
  | Ty_Constant Ty_CharLit -> Format.fprintf fmt "char"
  | Ty_Any -> Format.fprintf fmt "_"
  | Ty_Var s -> Format.fprintf fmt "'%s" s
  | Ty_Array t -> Format.fprintf fmt "@[<2>array<%a>@]" pp_ty t
  | Ty_Ref t -> Format.fprintf fmt "@[<2>ref<%a>@]" pp_ty t
  | Ty_Tuple ts ->
      Format.fprintf fmt "@[<1>(%a)@]"
        (Format.pp_print_list
           ~pp_sep:(fun fmt () -> Format.fprintf fmt ",@ ")
           pp_ty)
        ts
  | Ty_Arrow (params, ret) ->
      Format.fprintf fmt "@[<1>(%a) ->@ %a@]"
        (Format.pp_print_list
           ~pp_sep:(fun fmt () -> Format.fprintf fmt ",@ ")
           pp_ty)
        params pp_ty ret
  | Ty_Defined { name; args } ->
      let qual = name.name in
      if args = [] then Format.fprintf fmt "%s" qual
      else
        Format.fprintf fmt "@[<2>%s<%a>@]" qual
          (Format.pp_print_list
             ~pp_sep:(fun fmt () -> Format.fprintf fmt ",@ ")
             pp_ty)
          args

let rec pp_pattern fmt (p : pattern) =
  match p.node with
  | Pat_Unit -> Format.fprintf fmt "()"
  | Pat_BoolLit b -> Format.fprintf fmt "%s" b
  | Pat_IntLit i -> Format.fprintf fmt "%s" i
  | Pat_CharLit c -> Format.fprintf fmt "'%s'" c
  | Pat_FloatLit f -> Format.fprintf fmt "%s" f
  | Pat_StringLit s -> Format.fprintf fmt "\"%s\"" (String.escaped s)
  | Pat_Ident s -> Format.fprintf fmt "%s" s.name
  | Pat_Any -> Format.fprintf fmt "_"
  | Pat_Tuple { elements } ->
      Format.fprintf fmt "@[<1>(%a)@]"
        (Format.pp_print_list
           ~pp_sep:(fun fmt () -> Format.fprintf fmt ",@ ")
           pp_pattern)
        elements
  | Pat_Record { fields } ->
      Format.fprintf fmt "@[<2>{ @[<hv>%a@]@ }@]"
        (Format.pp_print_list
           ~pp_sep:(fun fmt () -> Format.fprintf fmt ";@ ")
           (fun fmt (f : pattern_record_field) ->
             match f.pattern with
             | None -> Format.fprintf fmt "%s" f.name.name
             | Some pat ->
                 Format.fprintf fmt "%s =@ %a" f.name.name pp_pattern pat))
        fields
  | Pat_Constructor { name; pattern = None } ->
      Format.fprintf fmt "%s" name.name
  | Pat_Constructor { name; pattern = Some pat } ->
      Format.fprintf fmt "%s(%a)" name.name pp_pattern pat

let pp_unop fmt (op : unop) =
  match op with
  | Unop_Logical Not -> Format.fprintf fmt "not"
  | Unop_Arithmetic Neg -> Format.fprintf fmt "-"
  | Unop_Bitwise BitNot -> Format.fprintf fmt "~"

let pp_binop fmt = function
  | Binop_Arithmetic Add -> Format.fprintf fmt "+"
  | Binop_Arithmetic Sub -> Format.fprintf fmt "-"
  | Binop_Arithmetic Mul -> Format.fprintf fmt "*"
  | Binop_Arithmetic Div -> Format.fprintf fmt "/"
  | Binop_Arithmetic Mod -> Format.fprintf fmt "%%"
  | Binop_Logical And -> Format.fprintf fmt "&&"
  | Binop_Logical Or -> Format.fprintf fmt "||"
  | Binop_Bitwise BitAnd -> Format.fprintf fmt "&"
  | Binop_Bitwise BitOr -> Format.fprintf fmt "|"
  | Binop_Bitwise BitXor -> Format.fprintf fmt "^"
  | Binop_Bitwise LShift -> Format.fprintf fmt "<<"
  | Binop_Bitwise RShift -> Format.fprintf fmt ">>"
  | Binop_Comparison Eq -> Format.fprintf fmt "=="
  | Binop_Comparison Ne -> Format.fprintf fmt "!="
  | Binop_Comparison Lt -> Format.fprintf fmt "<"
  | Binop_Comparison Le -> Format.fprintf fmt "<="
  | Binop_Comparison Gt -> Format.fprintf fmt ">"
  | Binop_Comparison Ge -> Format.fprintf fmt ">="

let rec pp_expr fmt (e : expr) =
  match e.expr_desc with
  | Exp_Constant c -> (
      match c.constant_desc with
      | Const_Unit -> Format.fprintf fmt "()"
      | Const_BoolLit b -> Format.fprintf fmt "%s" b
      | Const_IntLit i -> Format.fprintf fmt "%s" i
      | Const_FloatLit f -> Format.fprintf fmt "%s" f
      | Const_CharLit c' -> Format.fprintf fmt "'%s'" c'
      | Const_StringLit s -> Format.fprintf fmt "\"%s\"" (String.escaped s))
  | Exp_Ident i -> Format.fprintf fmt "%s" i.name
  | Exp_Tuple { elements } ->
      Format.fprintf fmt "@[<1>(%a)@]"
        (Format.pp_print_list
           ~pp_sep:(fun fmt () -> Format.fprintf fmt ",@ ")
           pp_expr)
        elements
  | Exp_Record { fields } ->
      Format.fprintf fmt "@[<2>{@ @[<hov>%a@]@ }@]"
        (Format.pp_print_list
           ~pp_sep:(fun fmt () -> Format.fprintf fmt ";@ ")
           (fun fmt f ->
             Format.fprintf fmt "@[<2>%s =@ %a@]" f.field_name.name pp_expr
               f.field_value))
        fields
  | Exp_VariantConstructor { name; arg } -> (
      match arg with
      | None -> Format.fprintf fmt "%s" name.name
      | Some inner -> Format.fprintf fmt "%s(%a)" name.name pp_expr inner)
  | Exp_ArrayCreate { size; _ } ->
      Format.fprintf fmt "array.create(..., %a)" pp_expr size
  | Exp_ArrayLength { arr } -> Format.fprintf fmt "array.length(%a)" pp_expr arr
  | Exp_ArrayGet { arr; idx } ->
      Format.fprintf fmt "array.get(%a, %a)" pp_expr arr pp_expr idx
  | Exp_ArraySet { arr; idx; value } ->
      Format.fprintf fmt "array.set(%a, %a, %a)" pp_expr arr pp_expr idx pp_expr
        value
  | Exp_UnOp { op; value } ->
      Format.fprintf fmt "@[<2>%a@ %a@]" pp_unop op pp_expr value
  | Exp_Ref { value } -> Format.fprintf fmt "@[<2>ref@ %a@]" pp_expr value
  | Exp_Deref { value } -> Format.fprintf fmt "@[<2>*@ %a@]" pp_expr value
  | Exp_BinOp { op; lvalue; rvalue } ->
      Format.fprintf fmt "@[<1>(%a@ %a@ %a)@]" pp_expr lvalue pp_binop op
        pp_expr rvalue
  | Exp_Lambda { params; body; ret_ty; _ } ->
      let pp_param fmt (p : param) =
        Format.fprintf fmt "%a" pp_pattern p.pattern;
        match p.param_ty with
        | None -> ()
        | Some ty -> Format.fprintf fmt ":@ %a" pp_ty ty
      in
      Format.fprintf fmt "@[<v 2>lambda(%a)%a {@ %a@;<0 -2>}@]"
        (Format.pp_print_list
           ~pp_sep:(fun fmt () -> Format.fprintf fmt ",@ ")
           pp_param)
        params
        (fun fmt -> function
          | None -> () | Some ty -> Format.fprintf fmt "@ -> %a" pp_ty ty)
        ret_ty pp_expr body
  | Exp_Apply { closure_fun; args } ->
      Format.fprintf fmt "@[<2>%a(%a)@]" pp_expr closure_fun
        (Format.pp_print_list
           ~pp_sep:(fun fmt () -> Format.fprintf fmt ",@ ")
           pp_expr)
        args
  | Exp_Let ld ->
      Format.fprintf fmt "@[<2>let %a =@ %a@]" pp_pattern ld.pattern pp_expr
        ld.value
  | Exp_Assign { target; value } ->
      Format.fprintf fmt "@[<2>%a =@ %a@]" pp_expr target pp_expr value
  | Exp_AssignRef { target; value } ->
      Format.fprintf fmt "@[<2>%a :=@ %a@]" pp_expr target pp_expr value
  | Exp_If { cond; then_branch; else_branch } -> (
      match else_branch with
      | None ->
          Format.fprintf fmt "@[<v 2>if %a then@ %a@]" pp_expr cond pp_expr
            then_branch
      | Some else_e ->
          Format.fprintf fmt "@[<v 2>if %a then@ %a@ else@ %a@]" pp_expr cond
            pp_expr then_branch pp_expr else_e)
  | Exp_While { cond; body } ->
      Format.fprintf fmt "@[<v 2>while %a do@ %a@]" pp_expr cond pp_expr body
  | Exp_ForIn { iter_var; iterable; body } ->
      Format.fprintf fmt "@[<v 2>for %a in %a do@ %a@]" pp_pattern iter_var
        pp_expr iterable pp_expr body
  | Exp_Loop { expr } -> Format.fprintf fmt "@[<v 2>loop@ %a@]" pp_expr expr
  | Exp_Break { expr_opt = None } -> Format.fprintf fmt "break"
  | Exp_Break { expr_opt = Some e1 } ->
      Format.fprintf fmt "@[<2>break %a@]" pp_expr e1
  | Exp_Continue -> Format.fprintf fmt "continue"
  | Exp_Return { expr_opt = None } -> Format.fprintf fmt "return"
  | Exp_Return { expr_opt = Some e1 } ->
      Format.fprintf fmt "@[<2>return %a@]" pp_expr e1
  | Exp_Seq { exprs } ->
      Format.fprintf fmt "@[<v 2>{@ %a@;<0 -2>}@]"
        (Format.pp_print_list
           ~pp_sep:(fun fmt () -> Format.fprintf fmt ";@ ")
           pp_expr)
        exprs
  | Exp_Match { expr = scrutinee; _ } ->
      Format.fprintf fmt "@[<2>match %a with ...@]" pp_expr scrutinee
  | Exp_Field { record; field_name } ->
      Format.fprintf fmt "%a.%s" pp_expr record field_name.name
  | Exp_Index { collection; index } ->
      Format.fprintf fmt "%a[%a]" pp_expr collection pp_expr index

(* -------------------------------------------------------------------------- *)
(* Convenience functions to get string output *)
(* -------------------------------------------------------------------------- *)

let string_of_ty ty = Format.asprintf "%a" pp_ty ty
let string_of_pattern p = Format.asprintf "%a" pp_pattern p
let string_of_expr e = Format.asprintf "%a" pp_expr e
let to_string = string_of_expr
