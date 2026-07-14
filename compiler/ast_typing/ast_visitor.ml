open Typed_ast

type 'acc visitor = {
  ty : 'acc visitor -> 'acc -> ty -> 'acc;
  expr : 'acc visitor -> 'acc -> expr -> 'acc;
  pattern : 'acc visitor -> 'acc -> pattern -> 'acc;
  pattern_case : 'acc visitor -> 'acc -> pattern_case -> 'acc;
  structure_item : 'acc visitor -> 'acc -> structure_item -> 'acc;
  signature_item : 'acc visitor -> 'acc -> signature_item -> 'acc;
  module_signature : 'acc visitor -> 'acc -> module_signature -> 'acc;
  module_structure : 'acc visitor -> 'acc -> module_structure -> 'acc;
}

let rec visit_ty_children (v : 'acc visitor) (acc : 'acc) (ty : ty) : 'acc =
  match ty.ty_desc with
  | TTy_Var _ | TTy_Any | TTy_Constant _ -> acc
  | TTy_Array inner -> v.ty v acc inner
  | TTy_Tuple tys -> List.fold_left (v.ty v) acc tys
  | TTy_Arrow (params, ret) ->
      let acc = List.fold_left (v.ty v) acc params in
      v.ty v acc ret
  | TTy_Defined { args; _ } -> List.fold_left (v.ty v) acc args

let rec visit_pattern_children (v : 'acc visitor) (acc : 'acc) (p : pattern) :
    'acc =
  match p.pattern_desc with
  | TPat_Unit | TPat_BoolLit _ | TPat_IntLit _ | TPat_CharLit _
  | TPat_FloatLit _ | TPat_StringLit _ | TPat_Ident _ | TPat_Wildcard ->
      acc
  | TPat_Tuple ps -> List.fold_left (v.pattern v) acc ps
  | TPat_Record fields ->
      List.fold_left
        (fun a (_, p_opt) -> Option.fold ~none:a ~some:(v.pattern v a) p_opt)
        acc fields
  | TPat_Constructor (_, p_opt) ->
      Option.fold ~none:acc ~some:(v.pattern v acc) p_opt
  | TPat_Collection (TPat_List ps, ty_opt)
  | TPat_Collection (TPat_Array ps, ty_opt)
  | TPat_Collection (TPat_Set ps, ty_opt) ->
      let acc = List.fold_left (v.pattern v) acc ps in
      Option.fold ~none:acc ~some:(v.ty v acc) ty_opt
  | TPat_Collection (TPat_Map kvs, ty_opt) ->
      let acc =
        List.fold_left
          (fun a (k, value) ->
            let a = v.pattern v a k in
            v.pattern v a value)
          acc kvs
      in
      Option.fold ~none:acc ~some:(v.ty v acc) ty_opt

let visit_param (v : 'acc visitor) (acc : 'acc) (p : param) : 'acc =
  let acc = v.pattern v acc p.pattern in
  Option.fold ~none:acc ~some:(v.ty v acc) p.param_ty

let visit_lambda (v : 'acc visitor) (acc : 'acc) (lam : lambda) : 'acc =
  let acc = List.fold_left (visit_param v) acc lam.params in
  let acc = v.expr v acc lam.body in
  Option.fold ~none:acc ~some:(v.ty v acc) lam.ret_ty

let visit_letdef (v : 'acc visitor) (acc : 'acc) (ld : letdef) : 'acc =
  let acc = v.pattern v acc ld.pattern in
  let acc = v.expr v acc ld.value in
  Option.fold ~none:acc ~some:(v.ty v acc) ld.ty_opt

let rec visit_expr_children (v : 'acc visitor) (acc : 'acc) (e : expr) : 'acc =
  match e.expr_desc with
  | TExp_Constant _ | TExp_Ident _ | TExp_Continue -> acc
  | TExp_Tuple es -> List.fold_left (v.expr v) acc es
  | TExp_Record fields ->
      List.fold_left (fun a f -> v.expr v a f.field_value) acc fields
  | TExp_Collection (TCol_List es)
  | TExp_Collection (TCol_Array es)
  | TExp_Collection (TCol_Set es) ->
      List.fold_left (v.expr v) acc es
  | TExp_Collection (TCol_Map kvs) ->
      List.fold_left
        (fun a (k, value) ->
          let a = v.expr v a k in
          v.expr v a value)
        acc kvs
  | TExp_VariantConstructor { args; _ } ->
      Option.fold ~none:acc ~some:(v.expr v acc) args
  | TExp_ArrayCreate { lambda_init; element_ty; size } ->
      let acc = visit_lambda v acc lambda_init in
      let acc = v.ty v acc element_ty in
      v.expr v acc size
  | TExp_ArrayLength e1 -> v.expr v acc e1
  | TExp_ArrayGet { arr; idx } ->
      let acc = v.expr v acc arr in
      v.expr v acc idx
  | TExp_ArraySet { arr; idx; value } ->
      let acc = v.expr v acc arr in
      let acc = v.expr v acc idx in
      v.expr v acc value
  | TExp_UnOp (_, e1) -> v.expr v acc e1
  | TExp_BinOp (_, l, r) ->
      let acc = v.expr v acc l in
      v.expr v acc r
  | TExp_Lambda lam -> visit_lambda v acc lam
  | TExp_Apply { closure_fun; args } ->
      let acc = v.expr v acc closure_fun in
      List.fold_left (v.expr v) acc args
  | TExp_Let ld -> visit_letdef v acc ld
  | TExp_Assign { target; value } ->
      let acc = v.expr v acc target in
      v.expr v acc value
  | TExp_If { cond; then_branch; else_branch } ->
      let acc = v.expr v acc cond in
      let acc = v.expr v acc then_branch in
      Option.fold ~none:acc ~some:(v.expr v acc) else_branch
  | TExp_While { cond; body } ->
      let acc = v.expr v acc cond in
      v.expr v acc body
  | TExp_ForIn { iter_var; iterable; body } ->
      let acc = v.pattern v acc iter_var in
      let acc = v.expr v acc iterable in
      v.expr v acc body
  | TExp_Loop body -> v.expr v acc body
  | TExp_Break e_opt | TExp_Return e_opt ->
      Option.fold ~none:acc ~some:(v.expr v acc) e_opt
  | TExp_Seq es -> List.fold_left (v.expr v) acc es
  | TExp_Match (scrutinee, cases) ->
      let acc = v.expr v acc scrutinee in
      List.fold_left (v.pattern_case v) acc cases
  | TExp_Field { record; _ } -> v.expr v acc record
  | TExp_Index { collection; index } ->
      let acc = v.expr v acc collection in
      v.expr v acc index

let visit_pattern_case_children (v : 'acc visitor) (acc : 'acc)
    (c : pattern_case) : 'acc =
  let acc = v.pattern v acc c.pattern in
  let acc = Option.fold ~none:acc ~some:(v.expr v acc) c.when_opt in
  v.expr v acc c.body

let visit_ty_decl (v : 'acc visitor) (acc : 'acc) (td : ty_decl) : 'acc =
  match td.def with
  | TTydef_Alias ty -> v.ty v acc ty
  | TTydef_Record fields ->
      List.fold_left (fun a f -> v.ty v a f.field_ty) acc fields
  | TTydef_Variant ctors ->
      List.fold_left
        (fun a c -> Option.fold ~none:a ~some:(v.ty v a) c.arg)
        acc ctors
  | TTydef_Abstract -> acc

let visit_signature_item_children (v : 'acc visitor) (acc : 'acc)
    (s : signature_item) : 'acc =
  match s.signature_item_desc with
  | TSig_Fun { params; ret_ty; _ } ->
      let acc = List.fold_left (v.ty v) acc params in
      v.ty v acc ret_ty
  | TSig_Type td -> visit_ty_decl v acc td
  | TSig_Module ms -> v.module_signature v acc ms

let visit_module_signature_children (v : 'acc visitor) (acc : 'acc)
    (ms : module_signature) : 'acc =
  List.fold_left (v.signature_item v) acc ms.signature_items

let visit_structure_item_children (v : 'acc visitor) (acc : 'acc)
    (s : structure_item) : 'acc =
  match s.structure_item_desc with
  | TStr_Let ld -> visit_letdef v acc ld
  | TStr_Fun { body; ty_opt; _ } ->
      let acc = v.expr v acc body in
      Option.fold ~none:acc ~some:(v.ty v acc) ty_opt
  | TStr_TypeDef td -> visit_ty_decl v acc td
  | TStr_ModuleStruct ms -> v.module_structure v acc ms
  | TStr_Signature sigs -> List.fold_left (v.signature_item v) acc sigs

let visit_module_structure_children (v : 'acc visitor) (acc : 'acc)
    (ms : module_structure) : 'acc =
  List.fold_left (v.structure_item v) acc ms.structure_items

let default_ty (v : 'acc visitor) (acc : 'acc) (ty : ty) : 'acc =
  visit_ty_children v acc ty

let default_expr (v : 'acc visitor) (acc : 'acc) (e : expr) : 'acc =
  visit_expr_children v acc e

let default_pattern (v : 'acc visitor) (acc : 'acc) (p : pattern) : 'acc =
  visit_pattern_children v acc p

let default_pattern_case (v : 'acc visitor) (acc : 'acc) (c : pattern_case) :
    'acc =
  visit_pattern_case_children v acc c

let default_structure_item (v : 'acc visitor) (acc : 'acc) (s : structure_item)
    : 'acc =
  visit_structure_item_children v acc s

let default_signature_item (v : 'acc visitor) (acc : 'acc) (s : signature_item)
    : 'acc =
  visit_signature_item_children v acc s

let default_module_signature (v : 'acc visitor) (acc : 'acc)
    (ms : module_signature) : 'acc =
  visit_module_signature_children v acc ms

let default_module_structure (v : 'acc visitor) (acc : 'acc)
    (ms : module_structure) : 'acc =
  visit_module_structure_children v acc ms

let identity_visitor : 'acc visitor =
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

let default_visitor = identity_visitor

let visit_expr (v : 'acc visitor) (acc : 'acc) (e : expr) : 'acc =
  v.expr v acc e

let visit_pattern (v : 'acc visitor) (acc : 'acc) (p : pattern) : 'acc =
  v.pattern v acc p

let visit_ty (v : 'acc visitor) (acc : 'acc) (ty : ty) : 'acc = v.ty v acc ty

let visit_pattern_case (v : 'acc visitor) (acc : 'acc) (c : pattern_case) : 'acc
    =
  v.pattern_case v acc c

let visit_structure_item (v : 'acc visitor) (acc : 'acc) (s : structure_item) :
    'acc =
  v.structure_item v acc s

let visit_program (v : 'acc visitor) (acc : 'acc) (prog : structure_item list) :
    'acc =
  List.fold_left (v.structure_item v) acc prog
