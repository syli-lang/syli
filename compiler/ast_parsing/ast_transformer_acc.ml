open Ast
open Types

type 'acc transformer = {
  ty : 'acc transformer -> 'acc -> ty -> 'acc * ty;
  expr : 'acc transformer -> 'acc -> expr -> 'acc * expr;
  pattern : 'acc transformer -> 'acc -> pattern -> 'acc * pattern;
  pattern_case :
    'acc transformer -> 'acc -> pattern_case -> 'acc * pattern_case;
  structure_item :
    'acc transformer -> 'acc -> structure_item -> 'acc * structure_item;
  signature_item :
    'acc transformer -> 'acc -> signature_item -> 'acc * signature_item;
  module_signature :
    'acc transformer -> 'acc -> module_signature -> 'acc * module_signature;
  module_structure :
    'acc transformer -> 'acc -> module_structure -> 'acc * module_structure;
}

let rec transform_ty (t : 'acc transformer) (acc : 'acc) (ty : ty) : 'acc * ty =
  match ty.ty_desc with
  | Ty_Constant _ | Ty_Var _ | Ty_Any -> (acc, ty)
  | Ty_Array inner ->
      let acc', inner' = t.ty t acc inner in
      (acc', { ty with ty_desc = Ty_Array inner' })
  | Ty_Ref inner ->
      let acc', inner' = t.ty t acc inner in
      (acc', { ty with ty_desc = Ty_Ref inner' })
  | Ty_Tuple tys ->
      let acc', tys' = List.fold_left_map (fun a ty' -> t.ty t a ty') acc tys in
      (acc', { ty with ty_desc = Ty_Tuple tys' })
  | Ty_Arrow (params, ret) ->
      let acc', params' =
        List.fold_left_map (fun a ty' -> t.ty t a ty') acc params
      in
      let acc'', ret' = t.ty t acc' ret in
      (acc'', { ty with ty_desc = Ty_Arrow (params', ret') })
  | Ty_Defined ({ args; _ } as defined) ->
      let acc', args' =
        List.fold_left_map (fun a ty' -> t.ty t a ty') acc args
      in
      (acc', { ty with ty_desc = Ty_Defined { defined with args = args' } })

let rec transform_pattern (t : 'acc transformer) (acc : 'acc) (p : pattern) :
    'acc * pattern =
  match p.node with
  | Pat_Unit | Pat_BoolLit _ | Pat_IntLit _ | Pat_CharLit _ | Pat_FloatLit _
  | Pat_StringLit _ | Pat_Ident _ | Pat_Any ->
      (acc, p)
  | Pat_Tuple { elements } ->
      let acc', elements' =
        List.fold_left_map (fun a p' -> t.pattern t a p') acc elements
      in
      (acc', { p with node = Pat_Tuple { elements = elements' } })
  | Pat_Record { fields } ->
      let acc', fields' =
        List.fold_left_map
          (fun a (f : pattern_record_field) ->
            match f.pattern with
            | None -> (a, f)
            | Some p' ->
                let a', p'' = t.pattern t a p' in
                (a', { f with pattern = Some p'' }))
          acc fields
      in
      (acc', { p with node = Pat_Record { fields = fields' } })
  | Pat_Constructor { name; pattern } ->
      let acc', pattern' =
        match pattern with
        | None -> (acc, None)
        | Some p' ->
            let a', p'' = t.pattern t acc p' in
            (a', Some p'')
      in
      (acc', { p with node = Pat_Constructor { name; pattern = pattern' } })

let transform_param (t : 'acc transformer) (acc : 'acc) (p : param) :
    'acc * param =
  let acc', pattern' = t.pattern t acc p.pattern in
  let acc'', param_ty' =
    match p.param_ty with
    | None -> (acc', None)
    | Some ty' ->
        let a', ty'' = t.ty t acc' ty' in
        (a', Some ty'')
  in
  (acc'', { p with pattern = pattern'; param_ty = param_ty' })

let transform_lambda (t : 'acc transformer) (acc : 'acc) (lam : lambda) :
    'acc * lambda =
  let acc', params' =
    List.fold_left_map (fun a p -> transform_param t a p) acc lam.params
  in
  let acc'', body' = t.expr t acc' lam.body in
  let acc''', ret_ty' =
    match lam.ret_ty with
    | None -> (acc'', None)
    | Some ty' ->
        let a', ty'' = t.ty t acc'' ty' in
        (a', Some ty'')
  in
  (acc''', { lam with params = params'; body = body'; ret_ty = ret_ty' })

let transform_letdef (t : 'acc transformer) (acc : 'acc) (ld : letdef) :
    'acc * letdef =
  let acc', pattern' = t.pattern t acc ld.pattern in
  let acc'', value' = t.expr t acc' ld.value in
  let acc''', ty_opt' =
    match ld.ty_opt with
    | None -> (acc'', None)
    | Some ty' ->
        let a', ty'' = t.ty t acc'' ty' in
        (a', Some ty'')
  in
  (acc''', { ld with pattern = pattern'; value = value'; ty_opt = ty_opt' })

let rec transform_expr (t : 'acc transformer) (acc : 'acc) (e : expr) :
    'acc * expr =
  match e.expr_desc with
  | Exp_Constant _ | Exp_Ident _ | Exp_Continue -> (acc, e)
  | Exp_Tuple { elements } ->
      let acc', elements' =
        List.fold_left_map (fun a e' -> t.expr t a e') acc elements
      in
      (acc', { e with expr_desc = Exp_Tuple { elements = elements' } })
  | Exp_Record { fields } ->
      let acc', fields' =
        List.fold_left_map
          (fun a f ->
            let a', v' = t.expr t a f.field_value in
            (a', { f with field_value = v' }))
          acc fields
      in
      (acc', { e with expr_desc = Exp_Record { fields = fields' } })
  | Exp_VariantConstructor { name; arg } ->
      let acc', arg' =
        match arg with
        | None -> (acc, None)
        | Some inner ->
            let a', inner' = t.expr t acc inner in
            (a', Some inner')
      in
      (acc', { e with expr_desc = Exp_VariantConstructor { name; arg = arg' } })
  | Exp_ArrayCreate { element_ty; size } ->
      let acc', element_ty' = t.ty t acc element_ty in
      let acc'', size' = t.expr t acc' size in
      ( acc'',
        {
          e with
          expr_desc = Exp_ArrayCreate { element_ty = element_ty'; size = size' };
        } )
  | Exp_ArrayLength { arr } ->
      let acc', arr' = t.expr t acc arr in
      (acc', { e with expr_desc = Exp_ArrayLength { arr = arr' } })
  | Exp_ArrayGet { arr; idx } ->
      let acc', arr' = t.expr t acc arr in
      let acc'', idx' = t.expr t acc' idx in
      (acc'', { e with expr_desc = Exp_ArrayGet { arr = arr'; idx = idx' } })
  | Exp_ArraySet { arr; idx; value } ->
      let acc', arr' = t.expr t acc arr in
      let acc'', idx' = t.expr t acc' idx in
      let acc''', value' = t.expr t acc'' value in
      ( acc''',
        {
          e with
          expr_desc = Exp_ArraySet { arr = arr'; idx = idx'; value = value' };
        } )
  | Exp_UnOp { op; value } ->
      let acc', value' = t.expr t acc value in
      (acc', { e with expr_desc = Exp_UnOp { op; value = value' } })
  | Exp_BinOp { op; lvalue; rvalue } ->
      let acc', lvalue' = t.expr t acc lvalue in
      let acc'', rvalue' = t.expr t acc' rvalue in
      ( acc'',
        {
          e with
          expr_desc = Exp_BinOp { op; lvalue = lvalue'; rvalue = rvalue' };
        } )
  | Exp_Ref { value } ->
      let acc', value' = t.expr t acc value in
      (acc', { e with expr_desc = Exp_Ref { value = value' } })
  | Exp_Deref { value } ->
      let acc', value' = t.expr t acc value in
      (acc', { e with expr_desc = Exp_Deref { value = value' } })
  | Exp_Lambda lam ->
      let acc', lam' = transform_lambda t acc lam in
      (acc', { e with expr_desc = Exp_Lambda lam' })
  | Exp_Apply { closure_fun; args } ->
      let acc', closure_fun' = t.expr t acc closure_fun in
      let acc'', args' =
        List.fold_left_map (fun a e' -> t.expr t a e') acc' args
      in
      ( acc'',
        {
          e with
          expr_desc = Exp_Apply { closure_fun = closure_fun'; args = args' };
        } )
  | Exp_Let ld ->
      let acc', ld' = transform_letdef t acc ld in
      (acc', { e with expr_desc = Exp_Let ld' })
  | Exp_Assign { target; value } ->
      let acc', target' = t.expr t acc target in
      let acc'', value' = t.expr t acc' value in
      ( acc'',
        { e with expr_desc = Exp_Assign { target = target'; value = value' } }
      )
  | Exp_AssignRef { target; value } ->
      let acc', target' = t.expr t acc target in
      let acc'', value' = t.expr t acc' value in
      ( acc'',
        {
          e with
          expr_desc = Exp_AssignRef { target = target'; value = value' };
        } )
  | Exp_If { cond; then_branch; else_branch } ->
      let acc', cond' = t.expr t acc cond in
      let acc'', then_branch' = t.expr t acc' then_branch in
      let acc''', else_branch' =
        match else_branch with
        | None -> (acc'', None)
        | Some e' ->
            let a', e'' = t.expr t acc'' e' in
            (a', Some e'')
      in
      ( acc''',
        {
          e with
          expr_desc =
            Exp_If
              {
                cond = cond';
                then_branch = then_branch';
                else_branch = else_branch';
              };
        } )
  | Exp_While { cond; body } ->
      let acc', cond' = t.expr t acc cond in
      let acc'', body' = t.expr t acc' body in
      (acc'', { e with expr_desc = Exp_While { cond = cond'; body = body' } })
  | Exp_ForIn { iter_var; iterable; body } ->
      let acc', iter_var' = t.pattern t acc iter_var in
      let acc'', iterable' = t.expr t acc' iterable in
      let acc''', body' = t.expr t acc'' body in
      ( acc''',
        {
          e with
          expr_desc =
            Exp_ForIn
              { iter_var = iter_var'; iterable = iterable'; body = body' };
        } )
  | Exp_Loop { expr } ->
      let acc', expr' = t.expr t acc expr in
      (acc', { e with expr_desc = Exp_Loop { expr = expr' } })
  | Exp_Break { expr_opt } ->
      let acc', expr_opt' =
        match expr_opt with
        | None -> (acc, None)
        | Some e' ->
            let a', e'' = t.expr t acc e' in
            (a', Some e'')
      in
      (acc', { e with expr_desc = Exp_Break { expr_opt = expr_opt' } })
  | Exp_Return { expr_opt } ->
      let acc', expr_opt' =
        match expr_opt with
        | None -> (acc, None)
        | Some e' ->
            let a', e'' = t.expr t acc e' in
            (a', Some e'')
      in
      (acc', { e with expr_desc = Exp_Return { expr_opt = expr_opt' } })
  | Exp_Seq { exprs } ->
      let acc', exprs' =
        List.fold_left_map (fun a e' -> t.expr t a e') acc exprs
      in
      (acc', { e with expr_desc = Exp_Seq { exprs = exprs' } })
  | Exp_Match { expr = scrutinee; cases } ->
      let acc', scrutinee' = t.expr t acc scrutinee in
      let acc'', cases' =
        List.fold_left_map (fun a c -> t.pattern_case t a c) acc' cases
      in
      ( acc'',
        { e with expr_desc = Exp_Match { expr = scrutinee'; cases = cases' } }
      )
  | Exp_Field { record; field_name } ->
      let acc', record' = t.expr t acc record in
      (acc', { e with expr_desc = Exp_Field { record = record'; field_name } })
  | Exp_Index { collection; index } ->
      let acc', collection' = t.expr t acc collection in
      let acc'', index' = t.expr t acc' index in
      ( acc'',
        {
          e with
          expr_desc = Exp_Index { collection = collection'; index = index' };
        } )

let transform_pattern_case (t : 'acc transformer) (acc : 'acc)
    (c : pattern_case) : 'acc * pattern_case =
  let acc', pattern' = t.pattern t acc c.pattern in
  let acc'', when_condition' =
    match c.when_condition with
    | None -> (acc', None)
    | Some e ->
        let a', e' = t.expr t acc' e in
        (a', Some e')
  in
  let acc''', body' = t.expr t acc'' c.body in
  ( acc''',
    {
      c with
      pattern = pattern';
      when_condition = when_condition';
      body = body';
    } )

let transform_ty_decl (t : 'acc transformer) (acc : 'acc) (td : ty_decl) :
    'acc * ty_decl =
  match td.def with
  | Tydef_Alias ty ->
      let acc', ty' = t.ty t acc ty in
      (acc', { td with def = Tydef_Alias ty' })
  | Tydef_Record fields ->
      let acc', fields' =
        List.fold_left_map
          (fun a f ->
            let a', ty' = t.ty t a f.field_ty in
            (a', { f with field_ty = ty' }))
          acc fields
      in
      (acc', { td with def = Tydef_Record fields' })
  | Tydef_Variant ctors ->
      let acc', ctors' =
        List.fold_left_map
          (fun a c ->
            let a', arg' =
              match c.arg with
              | None -> (a, None)
              | Some (Constr_ty ty) ->
                  let a'', ty' = t.ty t a ty in
                  (a'', Some (Constr_ty ty'))
              | Some (Constr_record fields) ->
                  let a'', fields' =
                    List.fold_left_map
                      (fun acc' f ->
                        let acc'', ty' = t.ty t acc' f.field_ty in
                        (acc'', { f with field_ty = ty' }))
                      a fields
                  in
                  (a'', Some (Constr_record fields'))
            in
            (a', { c with arg = arg' }))
          acc ctors
      in
      (acc', { td with def = Tydef_Variant ctors' })
  | Tydef_Abstract -> (acc, td)

let transform_signature_item (t : 'acc transformer) (acc : 'acc)
    (s : signature_item) : 'acc * signature_item =
  match s.signature_item_desc with
  | Sig_Value { name; params; value_ty; external_fn } ->
      let acc', params' =
        List.fold_left_map (fun a ty -> t.ty t a ty) acc params
      in
      let acc'', value_ty' = t.ty t acc' value_ty in
      ( acc'',
        {
          s with
          signature_item_desc =
            Sig_Value
              { name; params = params'; value_ty = value_ty'; external_fn };
        } )
  | Sig_Type td ->
      let acc', td' = transform_ty_decl t acc td in
      (acc', { s with signature_item_desc = Sig_Type td' })
  | Sig_Module ms ->
      let acc', ms' = t.module_signature t acc ms in
      (acc', { s with signature_item_desc = Sig_Module ms' })

let transform_module_signature (t : 'acc transformer) (acc : 'acc)
    (ms : module_signature) : 'acc * module_signature =
  let acc', signature_items' =
    List.fold_left_map
      (fun a s -> t.signature_item t a s)
      acc ms.signature_items
  in
  (acc', { ms with signature_items = signature_items' })

let transform_structure_item (t : 'acc transformer) (acc : 'acc)
    (s : structure_item) : 'acc * structure_item =
  match s.structure_item_desc with
  | Str_Let ld ->
      let acc', ld' = transform_letdef t acc ld in
      (acc', { s with structure_item_desc = Str_Let ld' })
  | Str_Fun { rec_flag; name; body; ty_opt } ->
      let acc', body' = t.expr t acc body in
      let acc'', ty_opt' =
        match ty_opt with
        | None -> (acc', None)
        | Some ty ->
            let a', ty' = t.ty t acc' ty in
            (a', Some ty')
      in
      ( acc'',
        {
          s with
          structure_item_desc =
            Str_Fun { rec_flag; name; body = body'; ty_opt = ty_opt' };
        } )
  | Str_TypeDef td ->
      let acc', td' = transform_ty_decl t acc td in
      (acc', { s with structure_item_desc = Str_TypeDef td' })
  | Str_ModuleStruct ms ->
      let acc', ms' = t.module_structure t acc ms in
      (acc', { s with structure_item_desc = Str_ModuleStruct ms' })
  | Str_Signature sigs ->
      let acc', sigs' =
        List.fold_left_map (fun a si -> t.signature_item t a si) acc sigs
      in
      (acc', { s with structure_item_desc = Str_Signature sigs' })

let transform_module_structure (t : 'acc transformer) (acc : 'acc)
    (ms : module_structure) : 'acc * module_structure =
  let acc', structure_items' =
    List.fold_left_map
      (fun a s -> t.structure_item t a s)
      acc ms.structure_items
  in
  (acc', { ms with structure_items = structure_items' })

let default_ty (t : 'acc transformer) (acc : 'acc) (ty : ty) : 'acc * ty =
  transform_ty t acc ty

let default_expr (t : 'acc transformer) (acc : 'acc) (e : expr) : 'acc * expr =
  transform_expr t acc e

let default_pattern (t : 'acc transformer) (acc : 'acc) (p : pattern) :
    'acc * pattern =
  transform_pattern t acc p

let default_pattern_case (t : 'acc transformer) (acc : 'acc) (c : pattern_case)
    : 'acc * pattern_case =
  transform_pattern_case t acc c

let default_structure_item (t : 'acc transformer) (acc : 'acc)
    (s : structure_item) : 'acc * structure_item =
  transform_structure_item t acc s

let default_signature_item (t : 'acc transformer) (acc : 'acc)
    (s : signature_item) : 'acc * signature_item =
  transform_signature_item t acc s

let default_module_signature (t : 'acc transformer) (acc : 'acc)
    (ms : module_signature) : 'acc * module_signature =
  transform_module_signature t acc ms

let default_module_structure (t : 'acc transformer) (acc : 'acc)
    (ms : module_structure) : 'acc * module_structure =
  transform_module_structure t acc ms

let identity_transformer : 'acc transformer =
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

let apply_expr (t : 'acc transformer) (acc : 'acc) (e : expr) : 'acc * expr =
  t.expr t acc e

let apply_pattern (t : 'acc transformer) (acc : 'acc) (p : pattern) :
    'acc * pattern =
  t.pattern t acc p

let apply_ty (t : 'acc transformer) (acc : 'acc) (ty : ty) : 'acc * ty =
  t.ty t acc ty

let apply_pattern_case (t : 'acc transformer) (acc : 'acc) (c : pattern_case) :
    'acc * pattern_case =
  t.pattern_case t acc c

let apply_structure_item (t : 'acc transformer) (acc : 'acc)
    (s : structure_item) : 'acc * structure_item =
  t.structure_item t acc s

let apply_program (t : 'acc transformer) (acc : 'acc)
    (prog : structure_item list) : 'acc * structure_item list =
  List.fold_left_map (fun a s -> t.structure_item t a s) acc prog

let transform_expr = apply_expr
let transform_pattern = apply_pattern
let transform_structure_item = apply_structure_item
let transform_pattern_case = apply_pattern_case
