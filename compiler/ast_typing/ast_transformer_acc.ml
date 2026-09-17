open Typed_ast

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
  | TTy_Var _ | TTy_Any | TTy_Constant _ -> (acc, ty)
  | TTy_Array inner ->
      let acc', inner' = t.ty t acc inner in
      (acc', { ty_desc = TTy_Array inner' })
  | TTy_Tuple tys ->
      let acc', tys' = List.fold_left_map (fun a ty' -> t.ty t a ty') acc tys in
      (acc', { ty_desc = TTy_Tuple tys' })
  | TTy_Arrow (param_ty, ret) ->
      let acc', param_ty' = t.ty t acc param_ty in
      let acc'', ret' = t.ty t acc' ret in
      (acc'', { ty_desc = TTy_Arrow (param_ty', ret') })
  | TTy_Defined ({ args; _ } as defined) ->
      let acc', args' =
        List.fold_left_map (fun a ty' -> t.ty t a ty') acc args
      in
      (acc', { ty_desc = TTy_Defined { defined with args = args' } })

let rec transform_pattern (t : 'acc transformer) (acc : 'acc) (p : pattern) :
    'acc * pattern =
  match p.pattern_desc with
  | TPat_Unit | TPat_BoolLit _ | TPat_IntLit _ | TPat_CharLit _
  | TPat_FloatLit _ | TPat_StringLit _ | TPat_Ident _ | TPat_Any ->
      (acc, p)
  | TPat_Tuple { elements } ->
      let acc', elements' =
        List.fold_left_map (fun a p' -> t.pattern t a p') acc elements
      in
      (acc', { p with pattern_desc = TPat_Tuple { elements = elements' } })
  | TPat_Record { fields } ->
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
      (acc', { p with pattern_desc = TPat_Record { fields = fields' } })
  | TPat_Constructor { tag; ident; pattern } ->
      let acc', pattern' =
        match pattern with
        | None -> (acc, None)
        | Some p' ->
            let a', p'' = t.pattern t acc p' in
            (a', Some p'')
      in
      ( acc',
        {
          p with
          pattern_desc = TPat_Constructor { tag; ident; pattern = pattern' };
        } )

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
  | TExp_Constant _ | TExp_Ident _ | TExp_Continue -> (acc, e)
  | TExp_Tuple { elements } ->
      let acc', elements' =
        List.fold_left_map (fun a e' -> t.expr t a e') acc elements
      in
      (acc', { e with expr_desc = TExp_Tuple { elements = elements' } })
  | TExp_Record { fields } ->
      let acc', fields' =
        List.fold_left_map
          (fun a f ->
            let a', v' = t.expr t a f.field_value in
            (a', { f with field_value = v' }))
          acc fields
      in
      (acc', { e with expr_desc = TExp_Record { fields = fields' } })
  | TExp_VariantConstructor { tag; name; arg } ->
      let acc', args' =
        match arg with
        | None -> (acc, None)
        | Some arg ->
            let a', arg' = t.expr t acc arg in
            (a', Some arg')
      in
      ( acc',
        {
          e with
          expr_desc = TExp_VariantConstructor { tag; name; arg = args' };
        } )
  | TExp_Array { element_ty; elements; size } ->
      let acc', element_ty' = t.ty t acc element_ty in
      let acc'', elements' =
        List.fold_left_map (fun a e' -> t.expr t a e') acc' elements
      in
      let acc''', size' = t.expr t acc'' size in
      ( acc''',
        {
          e with
          expr_desc =
            TExp_Array
              { element_ty = element_ty'; elements = elements'; size = size' };
        } )
  | TExp_Lambda lam ->
      let acc', lam' = transform_lambda t acc lam in
      (acc', { e with expr_desc = TExp_Lambda lam' })
  | TExp_Apply { closure_fun; args } ->
      let acc', closure_fun' = t.expr t acc closure_fun in
      let acc'', args' =
        List.fold_left_map (fun a e' -> t.expr t a e') acc' args
      in
      ( acc'',
        {
          e with
          expr_desc = TExp_Apply { closure_fun = closure_fun'; args = args' };
        } )
  | TExp_Let ld ->
      let acc', ld' = transform_letdef t acc ld in
      (acc', { e with expr_desc = TExp_Let ld' })
  | TExp_If { condition; then_branch; else_branch } ->
      let acc', cond' = t.expr t acc condition in
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
            TExp_If
              {
                condition = cond';
                then_branch = then_branch';
                else_branch = else_branch';
              };
        } )
  | TExp_While { condition; body } ->
      let acc', cond' = t.expr t acc condition in
      let acc'', body' = t.expr t acc' body in
      ( acc'',
        { e with expr_desc = TExp_While { condition = cond'; body = body' } } )
  | TExp_Loop { expr } ->
      let acc', expr' = t.expr t acc expr in
      (acc', { e with expr_desc = TExp_Loop { expr = expr' } })
  | TExp_Break { expr_opt } ->
      let acc', expr_opt' =
        match expr_opt with
        | None -> (acc, None)
        | Some e' ->
            let a', e'' = t.expr t acc e' in
            (a', Some e'')
      in
      (acc', { e with expr_desc = TExp_Break { expr_opt = expr_opt' } })
  | TExp_Return { expr_opt } ->
      let acc', expr_opt' =
        match expr_opt with
        | None -> (acc, None)
        | Some e' ->
            let a', e'' = t.expr t acc e' in
            (a', Some e'')
      in
      (acc', { e with expr_desc = TExp_Return { expr_opt = expr_opt' } })
  | TExp_Seq { exprs } ->
      let acc', exprs' =
        List.fold_left_map (fun a e' -> t.expr t a e') acc exprs
      in
      (acc', { e with expr_desc = TExp_Seq { exprs = exprs' } })
  | TExp_Match { expr = scrutinee; cases } ->
      let acc', scrutinee' = t.expr t acc scrutinee in
      let acc'', cases' =
        List.fold_left_map (fun a c -> t.pattern_case t a c) acc' cases
      in
      ( acc'',
        { e with expr_desc = TExp_Match { expr = scrutinee'; cases = cases' } }
      )
  | TExp_Field { record; field_name; field_idx } ->
      let acc', record' = t.expr t acc record in
      ( acc',
        {
          e with
          expr_desc = TExp_Field { record = record'; field_name; field_idx };
        } )
  | TExp_FieldSet { record; field_name; field_idx; value } ->
      let acc', record' = t.expr t acc record in
      let acc'', value' = t.expr t acc' value in
      ( acc'',
        {
          e with
          expr_desc =
            TExp_FieldSet
              { record = record'; field_name; field_idx; value = value' };
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
  | TTydef_Alias ty ->
      let acc', ty' = t.ty t acc ty in
      (acc', { td with def = TTydef_Alias ty' })
  | TTydef_Record fields ->
      let acc', fields' =
        List.fold_left_map
          (fun a f ->
            let a', ty' = t.ty t a f.field_ty in
            (a', { f with field_ty = ty' }))
          acc fields
      in
      (acc', { td with def = TTydef_Record fields' })
  | TTydef_Variant ctors ->
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
      (acc', { td with def = TTydef_Variant ctors' })
  | TTydef_Abstract -> (acc, td)

let transform_signature_item (t : 'acc transformer) (acc : 'acc)
    (s : signature_item) : 'acc * signature_item =
  match s.signature_item_desc with
  | TSig_Value { name; ty } ->
      let acc', value_ty' = t.ty t acc ty in
      ( acc',
        { s with signature_item_desc = TSig_Value { name; ty = value_ty' } } )
  | TSig_External { fname; ty; external_fn } ->
      let acc', ty' = t.ty t acc ty in
      ( acc',
        {
          s with
          signature_item_desc = TSig_External { fname; ty = ty'; external_fn };
        } )
  | TSig_Type td ->
      let acc', td' = transform_ty_decl t acc td in
      (acc', { s with signature_item_desc = TSig_Type td' })
  | TSig_ModuleSignature ms ->
      let acc', ms' = t.module_signature t acc ms in
      (acc', { s with signature_item_desc = TSig_ModuleSignature ms' })

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
  | TStr_Let ld ->
      let acc', ld' = transform_letdef t acc ld in
      (acc', { s with structure_item_desc = TStr_Let ld' })
  | TStr_External { fname; ty; external_fn } ->
      let acc', ty' = t.ty t acc ty in
      ( acc',
        {
          s with
          structure_item_desc = TStr_External { fname; ty = ty'; external_fn };
        } )
  | TStr_Type td ->
      let acc', td' = transform_ty_decl t acc td in
      (acc', { s with structure_item_desc = TStr_Type td' })
  | TStr_ModuleStructure ms ->
      let acc', ms' = t.module_structure t acc ms in
      (acc', { s with structure_item_desc = TStr_ModuleStructure ms' })
  | TStr_ModuleSignature ms ->
      let acc', ms' = t.module_signature t acc ms in
      (acc', { s with structure_item_desc = TStr_ModuleSignature ms' })

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
