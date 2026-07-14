open Core_ast

(* -------------------- *)
(* Types                *)
(* -------------------- *)

let string_of_constant_ty = function
  | CTy_Int64 -> "i64"
  | CTy_Int32 -> "i32"
  | CTy_Int16 -> "i16"
  | CTy_Int8 -> "i8"
  | CTy_UInt64 -> "u64"
  | CTy_UInt32 -> "u32"
  | CTy_UInt16 -> "u16"
  | CTy_UInt8 -> "u8"
  | CTy_Unit -> "unit"
  | CTy_Bool -> "bool"
  | CTy_Float -> "float"
  | CTy_Double -> "double"
  | CTy_StringLit -> "string"
  | CTy_CharLit -> "char"

let rec string_of_ty ty =
  match ty.ty_desc with
  | CTy_Var n -> Printf.sprintf "'a%d" n
  | CTy_Constant c -> string_of_constant_ty c
  | CTy_Arrow (params, ret) ->
      let ps = String.concat ", " (List.map string_of_ty params) in
      Printf.sprintf "(%s) -> %s" ps (string_of_ty ret)
  | CTy_Tuple ts ->
      Printf.sprintf "(%s)" (String.concat " * " (List.map string_of_ty ts))
  | CTy_Array t -> Printf.sprintf "array<%s>" (string_of_ty t)
  | CTy_Defined { name; args = [] } -> name.fullname
  | CTy_Defined { name; args } ->
      Printf.sprintf "%s<%s>" name.fullname
        (String.concat ", " (List.map string_of_ty args))

(* -------------------- *)
(* Operators            *)
(* -------------------- *)

let string_of_unop = function
  | CUnop_Logical CNot -> "!"
  | CUnop_Arithmetic CNeg -> "-"
  | CUnop_Bitwise CBitNot -> "~"

let string_of_binop = function
  | CBinop_Arithmetic CAdd -> "+"
  | CBinop_Arithmetic CSub -> "-"
  | CBinop_Arithmetic CMul -> "*"
  | CBinop_Arithmetic CDiv -> "/"
  | CBinop_Arithmetic CMod -> "%"
  | CBinop_Logical CAnd -> "&&"
  | CBinop_Logical COr -> "||"
  | CBinop_Bitwise CBitAnd -> "&"
  | CBinop_Bitwise CBitOr -> "|"
  | CBinop_Bitwise CBitXor -> "^"
  | CBinop_Bitwise CLShift -> "<<"
  | CBinop_Bitwise CRShift -> ">>"
  | CBinop_Comparison CEq -> "=="
  | CBinop_Comparison CNe -> "!="
  | CBinop_Comparison CLt -> "<"
  | CBinop_Comparison CLe -> "<="
  | CBinop_Comparison CGt -> ">"
  | CBinop_Comparison CGe -> ">="

(* -------------------- *)
(* Expressions          *)
(* -------------------- *)

let string_of_constant = function
  | CConst_Unit -> "()"
  | CConst_IntLit s -> s
  | CConst_FloatLit s -> s
  | CConst_BoolLit s -> s
  | CConst_StringLit s -> Printf.sprintf "%S" s
  | CConst_CharLit s -> Printf.sprintf "'%s'" s

let indent_str n = String.make (n * 2) ' '

(* Renders the expression content without a trailing ": ty" annotation.
   Used in positions where an annotation would break syntax or cause doubles
   (e.g. the function in an apply, the record in a field access). *)
let rec string_of_expr_inner ?(indent = 0) e =
  let p = indent_str indent in
  match e.node with
  | CExp_Constant c -> string_of_constant c
  | CExp_Ident id -> id.fullname
  | CExp_UnOp (op, x) ->
      Printf.sprintf "%s%s" (string_of_unop op) (string_of_expr ~indent x)
  | CExp_BinOp (op, l, r) ->
      Printf.sprintf "(%s %s %s)" (string_of_expr ~indent l)
        (string_of_binop op) (string_of_expr ~indent r)
  | CExp_Record fields ->
      let fs =
        String.concat "; "
          (List.map
             (fun f ->
               Printf.sprintf "%d = %s" f.field_idx
                 (string_of_expr ~indent f.field_value))
             fields)
      in
      Printf.sprintf "{ %s }" fs
  | CExp_VariantConstructor { tag; arg = None } -> Printf.sprintf "ctor(%d)" tag
  | CExp_VariantConstructor { tag; arg = Some a } ->
      Printf.sprintf "ctor(%d, %s)" tag (string_of_expr ~indent a)
  | CExp_Field { record; field_idx } ->
      (* Use inner for record so the annotation doesn't sit between record and .field *)
      Printf.sprintf "%s.%d" (string_of_expr_inner ~indent record) field_idx
  | CExp_FieldSet { record; field_idx; value } ->
      Printf.sprintf "%s.%d <- %s"
        (string_of_expr_inner ~indent record)
        field_idx
        (string_of_expr ~indent value)
  | CExp_ArrayCreate { init_fun; element_ty; size } ->
      Printf.sprintf "array_create<%s>[%s](%s)" (string_of_ty element_ty)
        (string_of_expr ~indent size)
        (string_of_lambda ~indent init_fun)
  | CExp_ArrayLength arr ->
      Printf.sprintf "array_length(%s)" (string_of_expr ~indent arr)
  | CExp_ArrayGet { arr; idx } ->
      Printf.sprintf "%s[%s]"
        (string_of_expr_inner ~indent arr)
        (string_of_expr ~indent idx)
  | CExp_ArraySet { arr; idx; value } ->
      Printf.sprintf "%s[%s] <- %s"
        (string_of_expr_inner ~indent arr)
        (string_of_expr ~indent idx)
        (string_of_expr ~indent value)
  | CExp_Lambda lam ->
      (* Return type is already shown in the lambda signature *)
      string_of_lambda ~indent lam
  | CExp_Apply { closure_fun; args } ->
      (* Use inner for closure_fun so its type annotation doesn't run into "(" *)
      let args_str =
        String.concat ", " (List.map (string_of_expr ~indent) args)
      in
      Printf.sprintf "%s(%s)"
        (string_of_expr_inner ~indent closure_fun)
        args_str
  | CExp_Let { rec_flag; name; value } ->
      let rec_str =
        match rec_flag with CRecursive -> "rec " | CNonRecursive -> ""
      in
      Printf.sprintf "let %s%s = %s" rec_str name.fullname
        (string_of_expr ~indent:(indent + 1) value)
  | CExp_Loop body ->
      Printf.sprintf "loop {\n%s\n%s}"
        (string_of_expr ~indent:(indent + 1) body)
        p
  | CExp_Break None -> "break"
  | CExp_Break (Some x) -> Printf.sprintf "break %s" (string_of_expr ~indent x)
  | CExp_Continue -> "continue"
  | CExp_Return None -> "return"
  | CExp_Return (Some x) ->
      Printf.sprintf "return %s" (string_of_expr ~indent x)
  | CExp_Seq exprs ->
      let stmts =
        List.map
          (fun e ->
            Printf.sprintf "%s%s"
              (indent_str (indent + 1))
              (string_of_expr ~indent:(indent + 1) e))
          exprs
      in
      Printf.sprintf "{\n%s\n%s}" (String.concat "\n" stmts) p
  | CExp_If { cond; then_branch; else_branch } ->
      let else_str =
        match else_branch with
        | None -> ""
        | Some e ->
            Printf.sprintf "\n%selse\n%s%s" p
              (indent_str (indent + 1))
              (string_of_expr ~indent:(indent + 1) e)
      in
      Printf.sprintf "if %s\n%s%s%s"
        (string_of_expr ~indent cond)
        (indent_str (indent + 1))
        (string_of_expr ~indent:(indent + 1) then_branch)
        else_str
  | CExp_Switch { scrutinee; cases; default } ->
      let cases_str =
        List.map
          (fun (v, body) ->
            Printf.sprintf "%s| %s -> %s"
              (indent_str (indent + 1))
              (string_of_expr ~indent:(indent + 1) v)
              (string_of_expr ~indent:(indent + 1) body))
          cases
      in
      let default_str =
        match default with
        | None -> ""
        | Some d ->
            Printf.sprintf "\n%s| _ -> %s"
              (indent_str (indent + 1))
              (string_of_expr ~indent:(indent + 1) d)
      in
      Printf.sprintf "switch %s {\n%s%s\n%s}"
        (string_of_expr ~indent scrutinee)
        (String.concat "\n" cases_str)
        default_str p
  | CExp_GetTagVariant x ->
      Printf.sprintf "get_tag(%s)" (string_of_expr ~indent x)

(* Renders an expression. Structural nodes (lambda, let, seq, if, loops,
   control flow) are printed without a trailing annotation since their types
   are either shown inline (lambda signature) or implied by their branches.
   Value-producing nodes append ": ty". *)
and string_of_expr ?(indent = 0) e =
  let inner = string_of_expr_inner ~indent e in
  match e.node with
  | CExp_Lambda _ | CExp_Let _ | CExp_Seq _ | CExp_If _ | CExp_Switch _
  | CExp_Loop _ | CExp_Break _ | CExp_Continue | CExp_Return _ ->
      inner
  | _ -> Printf.sprintf "%s : %s" inner (string_of_ty e.ty)

and string_of_lambda ?(indent = 0) lam =
  let params_str =
    String.concat ", " (List.map (fun id -> id.fullname) lam.params)
  in
  Printf.sprintf "fun (%s) : %s ->\n%s%s" params_str (string_of_ty lam.ret_ty)
    (indent_str (indent + 1))
    (string_of_expr ~indent:(indent + 1) lam.body)

(* -------------------- *)
(* Module items         *)
(* -------------------- *)

let string_of_ty_decl_desc = function
  | CTydef_Alias ty -> string_of_ty ty
  | CTydef_Variant ctors ->
      let ctors_str =
        String.concat " | "
          (List.map
             (fun c ->
               match c.arg with
               | None -> Printf.sprintf "ctor%d" c.id
               | Some t -> Printf.sprintf "ctor%d of %s" c.id (string_of_ty t))
             ctors)
      in
      ctors_str
  | CTydef_Record fields ->
      let fs =
        String.concat "; "
          (List.map
             (fun f ->
               let mut =
                 match f.field_mut with CMutable -> "mut " | CImmutable -> ""
               in
               Printf.sprintf "%s%d : %s" mut f.field_idx
                 (string_of_ty f.field_ty))
             fields)
      in
      Printf.sprintf "{ %s }" fs
  | CTydef_Abstract -> "<abstract>"

let string_of_ty_decl (td : ty_decl) =
  let params_str =
    match td.params with
    | [] -> ""
    | ps -> Printf.sprintf "<%s>" (String.concat ", " ps)
  in
  Printf.sprintf "type %s%s = %s" td.name.fullname params_str
    (string_of_ty_decl_desc td.def)

let string_of_structure_item item =
  match item.structure_item_desc with
  | CStr_Let { rec_flag; name; value } ->
      let rec_str =
        match rec_flag with CRecursive -> "rec " | CNonRecursive -> ""
      in
      Printf.sprintf "let %s%s = %s" rec_str name.fullname
        (string_of_expr ~indent:1 value)
  | CStr_TypeDef td -> string_of_ty_decl td

let string_of_module m =
  let buf = Buffer.create 256 in
  Printf.bprintf buf "module %s\n" m.name.fullname;
  List.iter
    (fun item -> Printf.bprintf buf "%s\n\n" (string_of_structure_item item))
    m.structure_items;
  Buffer.contents buf

let string_of_program = string_of_module
