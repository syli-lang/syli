open Typed_ast

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
    | TTy_Var _ | TTy_Any | TTy_Constant _ -> ty.ty_desc
    | TTy_Array inner -> TTy_Array (t.ty t inner)
    | TTy_Tuple tys -> TTy_Tuple (List.map (t.ty t) tys)
    | TTy_Arrow (params, ret) -> TTy_Arrow (List.map (t.ty t) params, t.ty t ret)
    | TTy_Defined ({ args; _ } as defined) ->
        TTy_Defined { defined with args = List.map (t.ty t) args }
  in
  { ty_desc }

let rec transform_pattern (t : transformer) (p : pattern) : pattern =
  let pattern_desc =
    match p.pattern_desc with
    | TPat_Unit | TPat_BoolLit _ | TPat_IntLit _ | TPat_CharLit _
    | TPat_FloatLit _ | TPat_StringLit _ | TPat_Ident _ | TPat_Wildcard ->
        p.pattern_desc
    | TPat_Tuple ps -> TPat_Tuple (List.map (t.pattern t) ps)
    | TPat_Record fields ->
        TPat_Record
          (List.map
             (fun (name, p_opt) -> (name, Option.map (t.pattern t) p_opt))
             fields)
    | TPat_Constructor (name, p_opt) ->
        TPat_Constructor (name, Option.map (t.pattern t) p_opt)
    | TPat_Collection (TPat_List ps, ty_opt) ->
        TPat_Collection
          (TPat_List (List.map (t.pattern t) ps), Option.map (t.ty t) ty_opt)
    | TPat_Collection (TPat_Array ps, ty_opt) ->
        TPat_Collection
          (TPat_Array (List.map (t.pattern t) ps), Option.map (t.ty t) ty_opt)
    | TPat_Collection (TPat_Set ps, ty_opt) ->
        TPat_Collection
          (TPat_Set (List.map (t.pattern t) ps), Option.map (t.ty t) ty_opt)
    | TPat_Collection (TPat_Map kvs, ty_opt) ->
        TPat_Collection
          ( TPat_Map
              (List.map (fun (k, v) -> (t.pattern t k, t.pattern t v)) kvs),
            Option.map (t.ty t) ty_opt )
  in
  { p with pattern_desc; ty = t.ty t p.ty }

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
    | TExp_Constant _ | TExp_Ident _ | TExp_Continue -> e.expr_desc
    | TExp_Tuple es -> TExp_Tuple (List.map (t.expr t) es)
    | TExp_Record fields ->
        TExp_Record
          (List.map
             (fun f -> { f with field_value = t.expr t f.field_value })
             fields)
    | TExp_Collection (TCol_List es) ->
        TExp_Collection (TCol_List (List.map (t.expr t) es))
    | TExp_Collection (TCol_Array es) ->
        TExp_Collection (TCol_Array (List.map (t.expr t) es))
    | TExp_Collection (TCol_Set es) ->
        TExp_Collection (TCol_Set (List.map (t.expr t) es))
    | TExp_Collection (TCol_Map kvs) ->
        TExp_Collection
          (TCol_Map (List.map (fun (k, v) -> (t.expr t k, t.expr t v)) kvs))
    | TExp_VariantConstructor { name; args } ->
        TExp_VariantConstructor { name; args = Option.map (t.expr t) args }
    | TExp_ArrayCreate { lambda_init; element_ty; size } ->
        TExp_ArrayCreate
          {
            lambda_init = transform_lambda t lambda_init;
            element_ty = t.ty t element_ty;
            size = t.expr t size;
          }
    | TExp_ArrayLength e1 -> TExp_ArrayLength (t.expr t e1)
    | TExp_ArrayGet { arr; idx } ->
        TExp_ArrayGet { arr = t.expr t arr; idx = t.expr t idx }
    | TExp_ArraySet { arr; idx; value } ->
        TExp_ArraySet
          { arr = t.expr t arr; idx = t.expr t idx; value = t.expr t value }
    | TExp_UnOp (op, e1) -> TExp_UnOp (op, t.expr t e1)
    | TExp_BinOp (op, l, r) -> TExp_BinOp (op, t.expr t l, t.expr t r)
    | TExp_Lambda lam -> TExp_Lambda (transform_lambda t lam)
    | TExp_Apply { closure_fun; args } ->
        TExp_Apply
          {
            closure_fun = t.expr t closure_fun;
            args = List.map (t.expr t) args;
          }
    | TExp_Let ld -> TExp_Let (transform_letdef t ld)
    | TExp_Assign { target; value } ->
        TExp_Assign { target = t.expr t target; value = t.expr t value }
    | TExp_If { cond; then_branch; else_branch } ->
        TExp_If
          {
            cond = t.expr t cond;
            then_branch = t.expr t then_branch;
            else_branch = Option.map (t.expr t) else_branch;
          }
    | TExp_While { cond; body } ->
        TExp_While { cond = t.expr t cond; body = t.expr t body }
    | TExp_ForIn { iter_var; iterable; body } ->
        TExp_ForIn
          {
            iter_var = t.pattern t iter_var;
            iterable = t.expr t iterable;
            body = t.expr t body;
          }
    | TExp_Loop body -> TExp_Loop (t.expr t body)
    | TExp_Break e_opt -> TExp_Break (Option.map (t.expr t) e_opt)
    | TExp_Return e_opt -> TExp_Return (Option.map (t.expr t) e_opt)
    | TExp_Seq es -> TExp_Seq (List.map (t.expr t) es)
    | TExp_Match (scrutinee, cases) ->
        TExp_Match (t.expr t scrutinee, List.map (t.pattern_case t) cases)
    | TExp_Field { record; field_name; idx } ->
        TExp_Field { record = t.expr t record; field_name; idx }
    | TExp_Index { collection; index } ->
        TExp_Index { collection = t.expr t collection; index = t.expr t index }
  in
  { e with expr_desc; ty = t.ty t e.ty }

let transform_pattern_case (t : transformer) (c : pattern_case) : pattern_case =
  {
    c with
    pattern = t.pattern t c.pattern;
    when_opt = Option.map (t.expr t) c.when_opt;
    body = t.expr t c.body;
    ty = t.ty t c.ty;
  }

let transform_ty_decl (t : transformer) (td : ty_decl) : ty_decl =
  let def =
    match td.def with
    | TTydef_Alias ty -> TTydef_Alias (t.ty t ty)
    | TTydef_Record fields ->
        TTydef_Record
          (List.map (fun f -> { f with field_ty = t.ty t f.field_ty }) fields)
    | TTydef_Variant ctors ->
        TTydef_Variant
          (List.map (fun c -> { c with arg = Option.map (t.ty t) c.arg }) ctors)
    | TTydef_Abstract -> TTydef_Abstract
  in
  { td with def }

let transform_signature_item (t : transformer) (s : signature_item) :
    signature_item =
  let signature_item_desc =
    match s.signature_item_desc with
    | TSig_Fun { name; params; ret_ty; external_fn } ->
        TSig_Fun
          {
            name;
            params = List.map (t.ty t) params;
            ret_ty = t.ty t ret_ty;
            external_fn;
          }
    | TSig_Type td -> TSig_Type (transform_ty_decl t td)
    | TSig_Module ms -> TSig_Module (t.module_signature t ms)
  in
  { s with signature_item_desc }

let transform_structure_item (t : transformer) (s : structure_item) :
    structure_item =
  let structure_item_desc =
    match s.structure_item_desc with
    | TStr_Let ld -> TStr_Let (transform_letdef t ld)
    | TStr_Fun { rec_flag; name; body; ty_opt } ->
        TStr_Fun
          {
            rec_flag;
            name;
            body = t.expr t body;
            ty_opt = Option.map (t.ty t) ty_opt;
          }
    | TStr_TypeDef td -> TStr_TypeDef (transform_ty_decl t td)
    | TStr_ModuleStruct ms -> TStr_ModuleStruct (t.module_structure t ms)
    | TStr_Signature sigs -> TStr_Signature (List.map (t.signature_item t) sigs)
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
