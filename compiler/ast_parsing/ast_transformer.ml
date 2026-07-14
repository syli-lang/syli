open Ast

type transformer = {
  ty : transformer -> ty -> ty;
  expr : transformer -> expr -> expr;
  pattern : transformer -> pattern -> pattern;
  pattern_case : transformer -> pattern_case -> pattern_case;
  structure_item : transformer -> structure_item -> structure_item;
  signature_item : transformer -> signature_item -> signature_item;
  module_signature : transformer -> module_signature -> module_signature;
  module_structure : transformer -> module_structure -> module_structure;
}

let rec transform_ty (t : transformer) (ty : ty) : ty =
  let ty_desc =
    match ty.ty_desc with
    | Ty_Constant _ | Ty_Var _ | Ty_Any -> ty.ty_desc
    | Ty_Array inner -> Ty_Array (t.ty t inner)
    | Ty_Tuple tys -> Ty_Tuple (List.map (t.ty t) tys)
    | Ty_Arrow (params, ret) -> Ty_Arrow (List.map (t.ty t) params, t.ty t ret)
    | Ty_Defined ({ args; _ } as defined) ->
        Ty_Defined { defined with args = List.map (t.ty t) args }
  in
  { ty with ty_desc }

let rec transform_pattern (t : transformer) (p : pattern) : pattern =
  let node =
    match p.node with
    | Pat_Unit | Pat_BoolLit _ | Pat_IntLit _ | Pat_CharLit _ | Pat_FloatLit _
    | Pat_StringLit _ | Pat_Ident _ | Pat_Wildcard ->
        p.node
    | Pat_Tuple ps -> Pat_Tuple (List.map (t.pattern t) ps)
    | Pat_Record fields ->
        Pat_Record
          (List.map
             (fun (name, p_opt) -> (name, Option.map (t.pattern t) p_opt))
             fields)
    | Pat_Constructor (name, p_opt) ->
        Pat_Constructor (name, Option.map (t.pattern t) p_opt)
    | Pat_Collection (Pat_List ps, ty_opt) ->
        Pat_Collection
          (Pat_List (List.map (t.pattern t) ps), Option.map (t.ty t) ty_opt)
    | Pat_Collection (Pat_Array ps, ty_opt) ->
        Pat_Collection
          (Pat_Array (List.map (t.pattern t) ps), Option.map (t.ty t) ty_opt)
    | Pat_Collection (Pat_Set ps, ty_opt) ->
        Pat_Collection
          (Pat_Set (List.map (t.pattern t) ps), Option.map (t.ty t) ty_opt)
    | Pat_Collection (Pat_Map kvs, ty_opt) ->
        Pat_Collection
          ( Pat_Map (List.map (fun (k, v) -> (t.pattern t k, t.pattern t v)) kvs),
            Option.map (t.ty t) ty_opt )
  in
  { p with node }

let transform_param (t : transformer) (p : param) : param =
  {
    p with
    pattern = t.pattern t p.pattern;
    param_ty = Option.map (t.ty t) p.param_ty;
  }

let transform_lambda (t : transformer) (lam : lambda) : lambda =
  {
    lam with
    params = List.map (transform_param t) lam.params;
    body = t.expr t lam.body;
    ret_ty = Option.map (t.ty t) lam.ret_ty;
  }

let transform_letdef (t : transformer) (ld : letdef) : letdef =
  {
    ld with
    pattern = t.pattern t ld.pattern;
    value = t.expr t ld.value;
    ty_opt = Option.map (t.ty t) ld.ty_opt;
  }

let rec transform_expr (t : transformer) (e : expr) : expr =
  let expr_desc =
    match e.expr_desc with
    | Exp_Constant _ | Exp_Ident _ | Exp_Continue -> e.expr_desc
    | Exp_Tuple es -> Exp_Tuple (List.map (t.expr t) es)
    | Exp_Record fields ->
        Exp_Record
          (List.map
             (fun f -> { f with field_value = t.expr t f.field_value })
             fields)
    | Exp_Collection (Col_List es) ->
        Exp_Collection (Col_List (List.map (t.expr t) es))
    | Exp_Collection (Col_Array es) ->
        Exp_Collection (Col_Array (List.map (t.expr t) es))
    | Exp_Collection (Col_Set es) ->
        Exp_Collection (Col_Set (List.map (t.expr t) es))
    | Exp_Collection (Col_Map kvs) ->
        Exp_Collection
          (Col_Map (List.map (fun (k, v) -> (t.expr t k, t.expr t v)) kvs))
    | Exp_VariantConstructor { name; arg } ->
        Exp_VariantConstructor { name; arg = Option.map (t.expr t) arg }
    | Exp_ArrayCreate { lambda_init; element_ty; size } ->
        Exp_ArrayCreate
          {
            lambda_init = transform_lambda t lambda_init;
            element_ty = t.ty t element_ty;
            size = t.expr t size;
          }
    | Exp_ArrayLength e1 -> Exp_ArrayLength (t.expr t e1)
    | Exp_ArrayGet { arr; idx } ->
        Exp_ArrayGet { arr = t.expr t arr; idx = t.expr t idx }
    | Exp_ArraySet { arr; idx; value } ->
        Exp_ArraySet
          { arr = t.expr t arr; idx = t.expr t idx; value = t.expr t value }
    | Exp_UnOp (op, e1) -> Exp_UnOp (op, t.expr t e1)
    | Exp_BinOp (op, l, r) -> Exp_BinOp (op, t.expr t l, t.expr t r)
    | Exp_Lambda lam -> Exp_Lambda (transform_lambda t lam)
    | Exp_Apply { closure_fun; args } ->
        Exp_Apply
          {
            closure_fun = t.expr t closure_fun;
            args = List.map (t.expr t) args;
          }
    | Exp_Let ld -> Exp_Let (transform_letdef t ld)
    | Exp_Assign { target; value } ->
        Exp_Assign { target = t.expr t target; value = t.expr t value }
    | Exp_If { cond; then_branch; else_branch } ->
        Exp_If
          {
            cond = t.expr t cond;
            then_branch = t.expr t then_branch;
            else_branch = Option.map (t.expr t) else_branch;
          }
    | Exp_While { cond; body } ->
        Exp_While { cond = t.expr t cond; body = t.expr t body }
    | Exp_ForIn { iter_var; iterable; body } ->
        Exp_ForIn
          {
            iter_var = t.pattern t iter_var;
            iterable = t.expr t iterable;
            body = t.expr t body;
          }
    | Exp_Loop body -> Exp_Loop (t.expr t body)
    | Exp_Break e_opt -> Exp_Break (Option.map (t.expr t) e_opt)
    | Exp_Return e_opt -> Exp_Return (Option.map (t.expr t) e_opt)
    | Exp_Seq es -> Exp_Seq (List.map (t.expr t) es)
    | Exp_Match (scrutinee, cases) ->
        Exp_Match (t.expr t scrutinee, List.map (t.pattern_case t) cases)
    | Exp_Field { record; field_name } ->
        Exp_Field { record = t.expr t record; field_name }
    | Exp_Index { collection; index } ->
        Exp_Index { collection = t.expr t collection; index = t.expr t index }
  in
  { e with expr_desc }

let transform_pattern_case (t : transformer) (c : pattern_case) : pattern_case =
  {
    c with
    pattern = t.pattern t c.pattern;
    when_opt = Option.map (t.expr t) c.when_opt;
    body = t.expr t c.body;
  }

let transform_ty_decl (t : transformer) (td : ty_decl) : ty_decl =
  let def =
    match td.def with
    | Tydef_Alias ty -> Tydef_Alias (t.ty t ty)
    | Tydef_Record fields ->
        Tydef_Record
          (List.map (fun f -> { f with field_ty = t.ty t f.field_ty }) fields)
    | Tydef_Variant ctors ->
        Tydef_Variant
          (List.map (fun c -> { c with arg = Option.map (t.ty t) c.arg }) ctors)
    | Tydef_Abstract -> Tydef_Abstract
  in
  { td with def }

let transform_signature_item (t : transformer) (s : signature_item) :
    signature_item =
  let signature_item_desc =
    match s.signature_item_desc with
    | Sig_Value { name; params; value_ty; external_fn } ->
        Sig_Value
          {
            name;
            params = List.map (t.ty t) params;
            value_ty = t.ty t value_ty;
            external_fn;
          }
    | Sig_Type td -> Sig_Type (transform_ty_decl t td)
    | Sig_Module ms -> Sig_Module (t.module_signature t ms)
  in
  { s with signature_item_desc }

let transform_structure_item (t : transformer) (s : structure_item) :
    structure_item =
  let structure_item_desc =
    match s.structure_item_desc with
    | Str_Let ld -> Str_Let (transform_letdef t ld)
    | Str_Fun { rec_flag; name; body; ty_opt } ->
        Str_Fun
          {
            rec_flag;
            name;
            body = t.expr t body;
            ty_opt = Option.map (t.ty t) ty_opt;
          }
    | Str_TypeDef td -> Str_TypeDef (transform_ty_decl t td)
    | Str_ModuleStruct ms -> Str_ModuleStruct (t.module_structure t ms)
    | Str_Signature sigs -> Str_Signature (List.map (t.signature_item t) sigs)
  in
  { s with structure_item_desc }

let transform_module_signature (t : transformer) (ms : module_signature) :
    module_signature =
  { ms with signature_items = List.map (t.signature_item t) ms.signature_items }

let transform_module_structure (t : transformer) (ms : module_structure) :
    module_structure =
  { ms with structure_items = List.map (t.structure_item t) ms.structure_items }

let default_ty (t : transformer) (ty : ty) : ty = transform_ty t ty
let default_expr (t : transformer) (e : expr) : expr = transform_expr t e

let default_pattern (t : transformer) (p : pattern) : pattern =
  transform_pattern t p

let default_pattern_case (t : transformer) (c : pattern_case) : pattern_case =
  transform_pattern_case t c

let default_structure_item (t : transformer) (s : structure_item) :
    structure_item =
  transform_structure_item t s

let default_signature_item (t : transformer) (s : signature_item) :
    signature_item =
  transform_signature_item t s

let default_module_signature (t : transformer) (ms : module_signature) :
    module_signature =
  transform_module_signature t ms

let default_module_structure (t : transformer) (ms : module_structure) :
    module_structure =
  transform_module_structure t ms

let identity_transformer : transformer =
  {
    ty = default_ty;
    expr = default_expr;
    pattern = default_pattern;
    pattern_case = default_pattern_case;
    structure_item = default_structure_item;
    signature_item = default_signature_item;
    module_signature = default_module_signature;
    module_structure = default_module_structure;
  }

let apply_expr (t : transformer) (e : expr) : expr = t.expr t e
let apply_pattern (t : transformer) (p : pattern) : pattern = t.pattern t p
let apply_ty (t : transformer) (ty : ty) : ty = t.ty t ty

let apply_pattern_case (t : transformer) (c : pattern_case) : pattern_case =
  t.pattern_case t c

let apply_structure_item (t : transformer) (s : structure_item) : structure_item
    =
  t.structure_item t s

let apply_program (t : transformer) (prog : structure_item list) :
    structure_item list =
  List.map (t.structure_item t) prog

let compose (t1 : transformer) (t2 : transformer) : transformer =
  {
    ty = (fun t ty -> t2.ty t (t1.ty t ty));
    expr = (fun t e -> t2.expr t (t1.expr t e));
    pattern = (fun t p -> t2.pattern t (t1.pattern t p));
    pattern_case = (fun t c -> t2.pattern_case t (t1.pattern_case t c));
    structure_item = (fun t s -> t2.structure_item t (t1.structure_item t s));
    signature_item = (fun t s -> t2.signature_item t (t1.signature_item t s));
    module_signature =
      (fun t ms -> t2.module_signature t (t1.module_signature t ms));
    module_structure =
      (fun t ms -> t2.module_structure t (t1.module_structure t ms));
  }

let transform_exprs_when (pred : expr -> bool) (f : expr -> expr) : transformer
    =
  {
    identity_transformer with
    expr =
      (fun t e ->
        let e' = transform_expr t e in
        if pred e' then f e' else e');
  }

let transform_patterns_when (pred : pattern -> bool) (f : pattern -> pattern) :
    transformer =
  {
    identity_transformer with
    pattern =
      (fun t p ->
        let p' = transform_pattern t p in
        if pred p' then f p' else p');
  }

let rename_idents (mapping : string -> string option) : transformer =
  {
    identity_transformer with
    expr =
      (fun t e ->
        let e' = transform_expr t e in
        match e'.expr_desc with
        | Exp_Ident idr -> (
            match mapping idr.name with
            | Some name' ->
                { e' with expr_desc = Exp_Ident { idr with name = name' } }
            | None -> e')
        | _ -> e');
    pattern =
      (fun t p ->
        let p' = transform_pattern t p in
        match p'.node with
        | Pat_Ident x -> (
            match mapping x.name with
            | Some x' -> { p' with node = Pat_Ident { x with name = x' } }
            | None -> p')
        | _ -> p');
  }
