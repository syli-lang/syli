open Core_ast

type 'acc visitor = {
  ty : 'acc visitor -> 'acc -> ty -> 'acc;
  expr : 'acc visitor -> 'acc -> expr -> 'acc;
  structure_item : 'acc visitor -> 'acc -> structure_item -> 'acc;
  signature_item : 'acc visitor -> 'acc -> signature_item -> 'acc;
  type_decl : 'acc visitor -> 'acc -> ty_decl -> 'acc;
}

let rec visit_ty_children (v : 'acc visitor) (acc : 'acc) (ty : ty) : 'acc =
  match ty.ty_desc with
  | CTy_Var _ | CTy_Constant _ -> acc
  | CTy_Arrow (params, ret) ->
      let acc' = List.fold_left (v.ty v) acc params in
      v.ty v acc' ret
  | CTy_Array inner -> v.ty v acc inner
  | CTy_Defined { args; _ } -> List.fold_left (v.ty v) acc args
  | CTy_Tuple elements -> List.fold_left (v.ty v) acc elements

let visit_lambda (v : 'acc visitor) (acc : 'acc) (lam : lambda) : 'acc =
  let acc' = v.expr v acc lam.body in
  v.ty v acc' lam.ret_ty

let rec visit_expr_children (v : 'acc visitor) (acc : 'acc) (e : expr) : 'acc =
  let acc' = v.ty v acc e.ty in
  match e.node with
  | CExp_Constant _ | CExp_Ident _ | CExp_Continue -> acc'
  | CExp_UnOp (_, inner) -> v.expr v acc' inner
  | CExp_BinOp (_, lhs, rhs) ->
      let acc'' = v.expr v acc' lhs in
      v.expr v acc'' rhs
  | CExp_VariantConstructor { arg; _ } ->
      Option.fold ~none:acc' ~some:(v.expr v acc') arg
  | CExp_Record fields ->
      List.fold_left
        (fun a (f : record_field) ->
          let a' = v.ty v a f.field_ty in
          v.expr v a' f.field_value)
        acc' fields
  | CExp_Field { record; _ } -> v.expr v acc' record
  | CExp_FieldSet { record; value; _ } ->
      let acc'' = v.expr v acc' record in
      v.expr v acc'' value
  | CExp_ArrayCreate { init_fun; element_ty; size; _ } ->
      let acc'' = visit_lambda v acc' init_fun in
      let acc''' = v.ty v acc'' element_ty in
      v.expr v acc''' size
  | CExp_ArrayLength inner -> v.expr v acc' inner
  | CExp_ArrayGet { arr; idx } ->
      let acc'' = v.expr v acc' arr in
      v.expr v acc'' idx
  | CExp_ArraySet { arr; idx; value } ->
      let acc'' = v.expr v acc' arr in
      let acc''' = v.expr v acc'' idx in
      v.expr v acc''' value
  | CExp_Lambda lam -> visit_lambda v acc' lam
  | CExp_Apply { closure_fun; args } ->
      let acc'' = v.expr v acc' closure_fun in
      List.fold_left (v.expr v) acc'' args
  | CExp_Let { value; _ } -> v.expr v acc' value
  | CExp_Loop body -> v.expr v acc' body
  | CExp_Break e_opt | CExp_Return e_opt ->
      Option.fold ~none:acc' ~some:(v.expr v acc') e_opt
  | CExp_Seq exprs -> List.fold_left (v.expr v) acc' exprs
  | CExp_If { cond; then_branch; else_branch } ->
      let acc'' = v.expr v acc' cond in
      let acc''' = v.expr v acc'' then_branch in
      Option.fold ~none:acc''' ~some:(v.expr v acc''') else_branch
  | CExp_Switch { scrutinee; cases; default } ->
      let acc'' = v.expr v acc' scrutinee in
      let acc''' =
        List.fold_left
          (fun a (on_expr, result_expr) ->
            let a' = v.expr v a on_expr in
            v.expr v a' result_expr)
          acc'' cases
      in
      Option.fold ~none:acc''' ~some:(v.expr v acc''') default
  | CExp_GetTagVariant inner -> v.expr v acc' inner

let visit_type_decl_children (v : 'acc visitor) (acc : 'acc) (td : ty_decl) :
    'acc =
  match td.def with
  | CTydef_Alias ty -> v.ty v acc ty
  | CTydef_Record fields ->
      List.fold_left
        (fun a (f : record_field_ty) -> v.ty v a f.field_ty)
        acc fields
  | CTydef_Abstract -> acc
  | CTydef_Variant constructors ->
      List.fold_left
        (fun a c ->
          match c.arg with None -> a | Some arg_ty -> v.ty v a arg_ty)
        acc constructors

let visit_signature_item_children (v : 'acc visitor) (acc : 'acc)
    (s : signature_item) : 'acc =
  match s.signature_item_desc with
  | CSig_Fun { params; ret_ty; _ } ->
      let acc' = List.fold_left (v.ty v) acc params in
      v.ty v acc' ret_ty
  | CSig_Type td -> v.type_decl v acc td

let visit_structure_item_children (v : 'acc visitor) (acc : 'acc)
    (d : structure_item) : 'acc =
  match d.structure_item_desc with
  | CStr_Let { value; _ } -> v.expr v acc value
  | CStr_TypeDef td -> v.type_decl v acc td

let default_ty (v : 'acc visitor) (acc : 'acc) (ty : ty) : 'acc =
  visit_ty_children v acc ty

let default_expr (v : 'acc visitor) (acc : 'acc) (e : expr) : 'acc =
  visit_expr_children v acc e

let default_structure_item (v : 'acc visitor) (acc : 'acc) (d : structure_item)
    : 'acc =
  visit_structure_item_children v acc d

let default_signature_item (v : 'acc visitor) (acc : 'acc) (s : signature_item)
    : 'acc =
  visit_signature_item_children v acc s

let default_type_decl (v : 'acc visitor) (acc : 'acc) (td : ty_decl) : 'acc =
  visit_type_decl_children v acc td

let identity_visitor : 'acc visitor =
  {
    ty = default_ty;
    expr = default_expr;
    structure_item = default_structure_item;
    signature_item = default_signature_item;
    type_decl = default_type_decl;
  }

let default_visitor = identity_visitor
let visit_ty (v : 'acc visitor) (acc : 'acc) (ty : ty) : 'acc = v.ty v acc ty

let visit_expr (v : 'acc visitor) (acc : 'acc) (e : expr) : 'acc =
  v.expr v acc e

let visit_structure_item (v : 'acc visitor) (acc : 'acc) (d : structure_item) :
    'acc =
  v.structure_item v acc d

let visit_signature_item (v : 'acc visitor) (acc : 'acc) (s : signature_item) :
    'acc =
  v.signature_item v acc s

let visit_type_decl (v : 'acc visitor) (acc : 'acc) (td : ty_decl) : 'acc =
  v.type_decl v acc td

let visit_program (v : 'acc visitor) (acc : 'acc) (prog : program_core) : 'acc =
  let acc' = List.fold_left (v.signature_item v) acc prog.signature_items in
  List.fold_left (v.structure_item v) acc' prog.structure_items

let collect_idents (prog : program_core) : string list =
  let visitor =
    {
      identity_visitor with
      expr =
        (fun v acc e ->
          let acc' =
            match e.node with
            | CExp_Ident { fullname; _ } -> fullname :: acc
            | CExp_Let { name = { fullname; _ }; _ } -> fullname :: acc
            | _ -> acc
          in
          visit_expr_children v acc' e);
    }
  in
  visit_program visitor [] prog

let collect_function_names (prog : program_core) : string list =
  let visitor =
    {
      identity_visitor with
      structure_item =
        (fun v acc d ->
          let acc' =
            match d.structure_item_desc with
            | CStr_Let
                {
                  name = { fullname; _ };
                  value = { node = CExp_Lambda _; _ };
                  _;
                } ->
                fullname :: acc
            | _ -> acc
          in
          visit_structure_item_children v acc' d);
    }
  in
  visit_program visitor [] prog

let collect_type_defs (prog : program_core) : (string * ty_decl) list =
  let visitor =
    {
      identity_visitor with
      structure_item =
        (fun v acc d ->
          let acc' =
            match d.structure_item_desc with
            | CStr_TypeDef td -> (td.name.fullname, td) :: acc
            | _ -> acc
          in
          visit_structure_item_children v acc' d);
    }
  in
  visit_program visitor [] prog

let count_expr_nodes (prog : program_core) : int =
  let visitor =
    {
      identity_visitor with
      expr =
        (fun v acc e ->
          let acc' = acc + 1 in
          visit_expr_children v acc' e);
    }
  in
  visit_program visitor 0 prog
