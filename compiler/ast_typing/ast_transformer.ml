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
    | TTy_Arrow (param, ret) -> TTy_Arrow (t.ty t param, t.ty t ret)
    | TTy_Defined ({ args; _ } as defined) ->
        TTy_Defined { defined with args = List.map (t.ty t) args }
  in
  { ty_desc }

let rec transform_pattern (t : transformer) (p : pattern) : pattern =
  let pattern_desc =
    match p.pattern_desc with
    | TPat_Unit | TPat_BoolLit _ | TPat_IntLit _ | TPat_CharLit _
    | TPat_FloatLit _ | TPat_StringLit _ | TPat_Ident _ | TPat_Any ->
        p.pattern_desc
    | TPat_Tuple { elements } ->
        TPat_Tuple { elements = List.map (t.pattern t) elements }
    | TPat_Record { fields } ->
        TPat_Record
          {
            fields =
              List.map
                (fun (f : pattern_record_field) ->
                  { f with pattern = Option.map (t.pattern t) f.pattern })
                fields;
          }
    | TPat_Constructor { tag; ident; pattern } ->
        TPat_Constructor
          { tag; ident; pattern = Option.map (t.pattern t) pattern }
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
    | TExp_Tuple { elements } ->
        TExp_Tuple { elements = List.map (t.expr t) elements }
    | TExp_Record { fields } ->
        TExp_Record
          {
            fields =
              List.map
                (fun f -> { f with field_value = t.expr t f.field_value })
                fields;
          }
    | TExp_VariantConstructor { tag; name; arg } ->
        TExp_VariantConstructor { tag; name; arg = Option.map (t.expr t) arg }
    | TExp_Array { element_ty; elements; size } ->
        TExp_Array
          {
            element_ty = t.ty t element_ty;
            elements = List.map (t.expr t) elements;
            size = t.expr t size;
          }
    | TExp_Lambda lam -> TExp_Lambda (transform_lambda t lam)
    | TExp_Apply { closure_fun; args } ->
        TExp_Apply
          {
            closure_fun = t.expr t closure_fun;
            args = List.map (t.expr t) args;
          }
    | TExp_Let ld -> TExp_Let (transform_letdef t ld)
    | TExp_If { condition; then_branch; else_branch } ->
        TExp_If
          {
            condition = t.expr t condition;
            then_branch = t.expr t then_branch;
            else_branch = Option.map (t.expr t) else_branch;
          }
    | TExp_While { condition; body } ->
        TExp_While { condition = t.expr t condition; body = t.expr t body }
    | TExp_Loop { expr } -> TExp_Loop { expr = t.expr t expr }
    | TExp_Break { expr_opt } ->
        TExp_Break { expr_opt = Option.map (t.expr t) expr_opt }
    | TExp_Return { expr_opt } ->
        TExp_Return { expr_opt = Option.map (t.expr t) expr_opt }
    | TExp_Seq { exprs } -> TExp_Seq { exprs = List.map (t.expr t) exprs }
    | TExp_Match { expr; cases } ->
        TExp_Match
          { expr = t.expr t expr; cases = List.map (t.pattern_case t) cases }
    | TExp_Field { record; field_name; field_idx } ->
        TExp_Field { record = t.expr t record; field_name; field_idx }
    | TExp_FieldSet { record; field_name; field_idx; value } ->
        TExp_FieldSet
          {
            record = t.expr t record;
            field_name;
            field_idx;
            value = t.expr t value;
          }
  in
  { e with expr_desc; ty = t.ty t e.ty }

let transform_pattern_case (t : transformer) (c : pattern_case) : pattern_case =
  {
    c with
    pattern = t.pattern t c.pattern;
    when_condition = Option.map (t.expr t) c.when_condition;
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
          (List.map
             (fun c ->
               {
                 c with
                 arg =
                   Option.map
                     (function
                       | Constr_ty ty -> Constr_ty (t.ty t ty)
                       | Constr_record fields ->
                           Constr_record
                             (List.map
                                (fun f ->
                                  { f with field_ty = t.ty t f.field_ty })
                                fields))
                     c.arg;
               })
             ctors)
    | TTydef_Abstract -> TTydef_Abstract
  in
  { td with def }

let transform_signature_item (t : transformer) (s : signature_item) :
    signature_item =
  let signature_item_desc =
    match s.signature_item_desc with
    | TSig_Value { name; ty } -> TSig_Value { name; ty = t.ty t ty }
    | TSig_External { fname; ty; external_fn } ->
        TSig_External { fname; ty = t.ty t ty; external_fn }
    | TSig_Type td -> TSig_Type (transform_ty_decl t td)
    | TSig_ModuleSignature ms -> TSig_ModuleSignature (t.module_signature t ms)
  in
  { s with signature_item_desc }

let transform_structure_item (t : transformer) (s : structure_item) :
    structure_item =
  let structure_item_desc =
    match s.structure_item_desc with
    | TStr_Let ld -> TStr_Let (transform_letdef t ld)
    | TStr_External { fname; ty; external_fn } ->
        TStr_External { fname; ty = t.ty t ty; external_fn }
    | TStr_Type td -> TStr_Type (transform_ty_decl t td)
    | TStr_ModuleStructure ms -> TStr_ModuleStructure (t.module_structure t ms)
    | TStr_ModuleSignature ms -> TStr_ModuleSignature (t.module_signature t ms)
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
