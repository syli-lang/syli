open Core_ast

type 'acc transformer = {
  ty : 'acc transformer -> 'acc -> ty -> 'acc * ty;
  expr : 'acc transformer -> 'acc -> expr -> 'acc * expr;
  structure_item :
    'acc transformer -> 'acc -> structure_item -> 'acc * structure_item;
  signature_item :
    'acc transformer -> 'acc -> signature_item -> 'acc * signature_item;
  type_decl : 'acc transformer -> 'acc -> ty_decl -> 'acc * ty_decl;
}

let rec transform_ty (t : 'acc transformer) (acc : 'acc) (ty : ty) : 'acc * ty =
  match ty.ty_desc with
  | CTy_Var _ | CTy_Constant _ -> (acc, ty)
  | CTy_Arrow (params, ret) ->
      let acc', params' =
        List.fold_left_map (fun a p -> t.ty t a p) acc params
      in
      let acc'', ret' = t.ty t acc' ret in
      (acc'', { ty_desc = CTy_Arrow (params', ret') })
  | CTy_Array inner ->
      let acc', inner' = t.ty t acc inner in
      (acc', { ty_desc = CTy_Array inner' })
  | CTy_Defined ({ args; _ } as named) ->
      let acc', args' = List.fold_left_map (fun a p -> t.ty t a p) acc args in
      (acc', { ty_desc = CTy_Defined { named with args = args' } })
  | CTy_Tuple elements ->
      let acc', elements' =
        List.fold_left_map (fun a p -> t.ty t a p) acc elements
      in
      (acc', { ty_desc = CTy_Tuple elements' })

let transform_lambda (t : 'acc transformer) (acc : 'acc) (lam : lambda) :
    'acc * lambda =
  let acc', body' = t.expr t acc lam.body in
  let acc'', ret_ty' = t.ty t acc' lam.ret_ty in
  (acc'', { lam with body = body'; ret_ty = ret_ty' })

let rec transform_expr (t : 'acc transformer) (acc : 'acc) (e : expr) :
    'acc * expr =
  let acc', expr_ty' = t.ty t acc e.ty in
  let acc'', node' =
    match e.node with
    | CExp_Constant _ | CExp_Ident _ | CExp_Continue -> (acc', e.node)
    | CExp_UnOp (op, inner) ->
        let a, inner' = t.expr t acc' inner in
        (a, CExp_UnOp (op, inner'))
    | CExp_BinOp (op, lhs, rhs) ->
        let a, lhs' = t.expr t acc' lhs in
        let a', rhs' = t.expr t a rhs in
        (a', CExp_BinOp (op, lhs', rhs'))
    | CExp_VariantConstructor { tag; arg } ->
        let a, arg' =
          match arg with
          | None -> (acc', None)
          | Some inner ->
              let st, inner' = t.expr t acc' inner in
              (st, Some inner')
        in
        (a, CExp_VariantConstructor { tag; arg = arg' })
    | CExp_Record fields ->
        let a, fields' =
          List.fold_left_map
            (fun st (f : record_field) ->
              let st', field_ty' = t.ty t st f.field_ty in
              let st'', field_value' = t.expr t st' f.field_value in
              (st'', { f with field_ty = field_ty'; field_value = field_value' }))
            acc' fields
        in
        (a, CExp_Record fields')
    | CExp_Field { record; field_idx } ->
        let a, record' = t.expr t acc' record in
        (a, CExp_Field { record = record'; field_idx })
    | CExp_FieldSet { record; field_idx; value } ->
        let a, record' = t.expr t acc' record in
        let a', value' = t.expr t a value in
        (a', CExp_FieldSet { record = record'; field_idx; value = value' })
    | CExp_ArrayCreate { init_fun; element_ty; size } ->
        let a, init_fun' = transform_lambda t acc' init_fun in
        let a', element_ty' = t.ty t a element_ty in
        let a'', size' = t.expr t a' size in
        ( a'',
          CExp_ArrayCreate
            { init_fun = init_fun'; element_ty = element_ty'; size = size' } )
    | CExp_ArrayLength inner ->
        let a, inner' = t.expr t acc' inner in
        (a, CExp_ArrayLength inner')
    | CExp_ArrayGet { arr; idx } ->
        let a, arr' = t.expr t acc' arr in
        let a', idx' = t.expr t a idx in
        (a', CExp_ArrayGet { arr = arr'; idx = idx' })
    | CExp_ArraySet { arr; idx; value } ->
        let a, arr' = t.expr t acc' arr in
        let a', idx' = t.expr t a idx in
        let a'', value' = t.expr t a' value in
        (a'', CExp_ArraySet { arr = arr'; idx = idx'; value = value' })
    | CExp_Lambda lam ->
        let a, lam' = transform_lambda t acc' lam in
        (a, CExp_Lambda lam')
    | CExp_Apply { closure_fun; args } ->
        let a, closure_fun' = t.expr t acc' closure_fun in
        let a', args' =
          List.fold_left_map (fun st arg -> t.expr t st arg) a args
        in
        (a', CExp_Apply { closure_fun = closure_fun'; args = args' })
    | CExp_Let { rec_flag; name; value } ->
        let a, value' = t.expr t acc' value in
        (a, CExp_Let { rec_flag; name; value = value' })
    | CExp_Loop body ->
        let a, body' = t.expr t acc' body in
        (a, CExp_Loop body')
    | CExp_Break e_opt ->
        let a, e_opt' =
          match e_opt with
          | None -> (acc', None)
          | Some inner ->
              let st, inner' = t.expr t acc' inner in
              (st, Some inner')
        in
        (a, CExp_Break e_opt')
    | CExp_Return e_opt ->
        let a, e_opt' =
          match e_opt with
          | None -> (acc', None)
          | Some inner ->
              let st, inner' = t.expr t acc' inner in
              (st, Some inner')
        in
        (a, CExp_Return e_opt')
    | CExp_Seq items ->
        let a, items' =
          List.fold_left_map (fun st item -> t.expr t st item) acc' items
        in
        (a, CExp_Seq items')
    | CExp_If { cond; then_branch; else_branch } ->
        let a, cond' = t.expr t acc' cond in
        let a', then_branch' = t.expr t a then_branch in
        let a'', else_branch' =
          match else_branch with
          | None -> (a', None)
          | Some inner ->
              let st, inner' = t.expr t a' inner in
              (st, Some inner')
        in
        ( a'',
          CExp_If
            {
              cond = cond';
              then_branch = then_branch';
              else_branch = else_branch';
            } )
    | CExp_Switch { scrutinee; cases; default } ->
        let a, scrutinee' = t.expr t acc' scrutinee in
        let a', cases' =
          List.fold_left_map
            (fun st (on_expr, result_expr) ->
              let st', on_expr' = t.expr t st on_expr in
              let st'', result_expr' = t.expr t st' result_expr in
              (st'', (on_expr', result_expr')))
            a cases
        in
        let a'', default' =
          match default with
          | None -> (a', None)
          | Some inner ->
              let st, inner' = t.expr t a' inner in
              (st, Some inner')
        in
        ( a'',
          CExp_Switch
            { scrutinee = scrutinee'; cases = cases'; default = default' } )
    | CExp_GetTagVariant inner ->
        let a, inner' = t.expr t acc' inner in
        (a, CExp_GetTagVariant inner')
  in
  (acc'', { e with node = node'; ty = expr_ty' })

let transform_type_decl (t : 'acc transformer) (acc : 'acc) (td : ty_decl) :
    'acc * ty_decl =
  match td.def with
  | CTydef_Alias ty ->
      let acc', ty' = t.ty t acc ty in
      (acc', { td with def = CTydef_Alias ty' })
  | CTydef_Record fields ->
      let acc', fields' =
        List.fold_left_map
          (fun st (f : record_field_ty) ->
            let st', field_ty' = t.ty t st f.field_ty in
            (st', { f with field_ty = field_ty' }))
          acc fields
      in
      (acc', { td with def = CTydef_Record fields' })
  | CTydef_Abstract -> (acc, td)
  | CTydef_Variant constructors ->
      let acc', constructors' =
        List.fold_left_map
          (fun st c ->
            match c.arg with
            | None -> (st, c)
            | Some arg_ty ->
                let st', arg_ty' = t.ty t st arg_ty in
                (st', { c with arg = Some arg_ty' }))
          acc constructors
      in
      (acc', { td with def = CTydef_Variant constructors' })

let transform_signature_item (t : 'acc transformer) (acc : 'acc)
    (s : signature_item) : 'acc * signature_item =
  match s.signature_item_desc with
  | CSig_Fun { name; params; ret_ty; external_fn } ->
      let acc', params' =
        List.fold_left_map (fun a ty -> t.ty t a ty) acc params
      in
      let acc'', ret_ty' = t.ty t acc' ret_ty in
      ( acc'',
        {
          s with
          signature_item_desc =
            CSig_Fun { name; params = params'; ret_ty = ret_ty'; external_fn };
        } )
  | CSig_Type type_decl ->
      let acc', type_decl' = t.type_decl t acc type_decl in
      (acc', { s with signature_item_desc = CSig_Type type_decl' })

let transform_structure_item (t : 'acc transformer) (acc : 'acc)
    (d : structure_item) : 'acc * structure_item =
  match d.structure_item_desc with
  | CStr_Let { rec_flag; name; value } ->
      let a, value' = t.expr t acc value in
      ( a,
        {
          d with
          structure_item_desc = CStr_Let { rec_flag; name; value = value' };
        } )
  | CStr_TypeDef type_decl ->
      let a, type_decl' = t.type_decl t acc type_decl in
      (a, { d with structure_item_desc = CStr_TypeDef type_decl' })

let transform_program (t : 'acc transformer) (acc : 'acc) (p : program_core) :
    'acc * program_core =
  let acc', signature_items' =
    List.fold_left_map
      (fun st s -> t.signature_item t st s)
      acc p.signature_items
  in
  let acc'', structure_items' =
    List.fold_left_map
      (fun st d -> t.structure_item t st d)
      acc' p.structure_items
  in
  ( acc'',
    {
      p with
      signature_items = signature_items';
      structure_items = structure_items';
    } )

let default_ty (t : 'acc transformer) (acc : 'acc) (ty : ty) : 'acc * ty =
  transform_ty t acc ty

let default_expr (t : 'acc transformer) (acc : 'acc) (e : expr) : 'acc * expr =
  transform_expr t acc e

let default_structure_item (t : 'acc transformer) (acc : 'acc)
    (d : structure_item) : 'acc * structure_item =
  transform_structure_item t acc d

let default_signature_item (t : 'acc transformer) (acc : 'acc)
    (s : signature_item) : 'acc * signature_item =
  transform_signature_item t acc s

let default_type_decl (t : 'acc transformer) (acc : 'acc) (td : ty_decl) :
    'acc * ty_decl =
  transform_type_decl t acc td

let identity_transformer : 'acc transformer =
  {
    ty = default_ty;
    expr = default_expr;
    structure_item = default_structure_item;
    signature_item = default_signature_item;
    type_decl = default_type_decl;
  }

let apply_ty (t : 'acc transformer) (acc : 'acc) (ty : ty) : 'acc * ty =
  t.ty t acc ty

let apply_expr (t : 'acc transformer) (acc : 'acc) (e : expr) : 'acc * expr =
  t.expr t acc e

let apply_structure_item (t : 'acc transformer) (acc : 'acc)
    (d : structure_item) : 'acc * structure_item =
  t.structure_item t acc d

let apply_signature_item (t : 'acc transformer) (acc : 'acc)
    (s : signature_item) : 'acc * signature_item =
  t.signature_item t acc s

let apply_type_decl (t : 'acc transformer) (acc : 'acc) (td : ty_decl) :
    'acc * ty_decl =
  t.type_decl t acc td

let apply_program (t : 'acc transformer) (acc : 'acc) (p : program_core) :
    'acc * program_core =
  transform_program t acc p
