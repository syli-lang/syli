open Syli_parsing.Ast
open Typed_ast
open Env
open Infer_helpers
open Parse_ty
open Ty
module Parsing_ast = Syli_parsing.Ast

let rec arrow_ty_of_params (params : ty list) (ret : ty) : ty =
  match params with
  | [] -> ret
  | param :: params -> mk_ty (TTy_Arrow (param, arrow_ty_of_params params ret))

let apply_expr_ty (ctx : infer_ctx) (e : expr) : expr =
  { e with ty = apply_ty ctx e.ty }

let apply_param_ty (ctx : infer_ctx) (p : param) : param =
  { p with param_ty = Option.map (apply_ty ctx) p.param_ty }

let unify_record_expr_fields_with_decl (ctx : infer_ctx)
    (decl_fields : record_field_decl list)
    (fields : (ident * expr * location) list) : infer_ctx * int list =
  let find_decl_field name =
    List.find_opt
      (fun (decl_field : record_field_decl) ->
        decl_field.field_name.name = name)
      decl_fields
  in
  List.fold_left_map
    (fun ctx ((name, value, loc) : ident * expr * location) ->
      match find_decl_field name.name with
      | None ->
          raise
            (Type_error
               (Some loc, Printf.sprintf "unknown record field '%s'" name.name))
      | Some decl_field ->
          let ctx = unify_into ~loc ctx value.ty decl_field.field_ty in
          (ctx, decl_field.field_idx))
    ctx fields

let unify_record_pattern_fields_with_decl (ctx : infer_ctx)
    (decl_fields : record_field_decl list)
    (fields : (ident * pattern option * location) list) : infer_ctx * int list =
  let find_decl_field name =
    List.find_opt
      (fun (decl_field : record_field_decl) ->
        decl_field.field_name.name = name)
      decl_fields
  in
  List.fold_left_map
    (fun ctx ((name, pattern, loc) : ident * pattern option * location) ->
      match find_decl_field name.name with
      | None ->
          raise
            (Type_error
               (Some loc, Printf.sprintf "unknown record field '%s'" name.name))
      | Some decl_field ->
          let ctx =
            match pattern with
            | None -> ctx
            | Some p -> unify_into ~loc:p.loc ctx p.ty decl_field.field_ty
          in
          (ctx, decl_field.field_idx))
    ctx fields

let rec infer_pattern (ctx : infer_ctx) (p : Parsing_ast.pattern) :
    infer_ctx * pattern =
  let loc = loc_of_parsing p.loc in
  match p.node with
  | Parsing_ast.Pat_Unit ->
      let ty = mk_ty (TTy_Constant TTy_Unit) in
      (ctx, { id = p.id; pattern_desc = TPat_Unit; loc; ty })
  | Parsing_ast.Pat_BoolLit s ->
      let ty = mk_ty (TTy_Constant TTy_Bool) in
      (ctx, { id = p.id; pattern_desc = TPat_BoolLit s; loc; ty })
  | Parsing_ast.Pat_IntLit s ->
      let ty = mk_ty (TTy_Constant TTy_Int64) in
      (ctx, { id = p.id; pattern_desc = TPat_IntLit s; loc; ty })
  | Parsing_ast.Pat_CharLit s ->
      let ty = mk_ty (TTy_Constant TTy_Char) in
      (ctx, { id = p.id; pattern_desc = TPat_CharLit s; loc; ty })
  | Parsing_ast.Pat_StringLit s ->
      let ty = mk_ty (TTy_Constant TTy_String) in
      (ctx, { id = p.id; pattern_desc = TPat_StringLit s; loc; ty })
  | Parsing_ast.Pat_FloatLit s ->
      let ty = mk_ty (TTy_Constant TTy_F64) in
      (ctx, { id = p.id; pattern_desc = TPat_FloatLit s; loc; ty })
  | Parsing_ast.Pat_Ident name ->
      if name.name = "_" then
        (ctx, { id = p.id; pattern_desc = TPat_Any; loc; ty = mk_ty TTy_Any })
      else
        let ctx, ty = fresh_ty ctx in
        let env = TyEnv.extend name.name { vars = []; body = ty } ctx.env in
        ( { ctx with env },
          {
            id = p.id;
            pattern_desc = TPat_Ident (ident_of_parsing name);
            loc;
            ty;
          } )
  | Parsing_ast.Pat_Tuple { elements } ->
      let ctx, pats_tys =
        List.fold_left_map
          (fun ctx p ->
            let ctx, tp = infer_pattern ctx p in
            (ctx, (tp, tp.ty)))
          ctx elements
      in
      let pats, tys = List.split pats_tys in
      let ty = { ty_desc = TTy_Tuple tys } in
      ( ctx,
        { id = p.id; pattern_desc = TPat_Tuple { elements = pats }; loc; ty } )
  | Parsing_ast.Pat_Record { fields } -> (
      let ctx, infos =
        List.fold_left_map
          (fun ctx (f : Parsing_ast.pattern_record_field) ->
            let ctx, pattern =
              match f.value with
              | None -> (ctx, None)
              | Some p ->
                  let ctx, tp = infer_pattern ctx p in
                  (ctx, Some tp)
            in
            (ctx, (ident_of_parsing f.name, pattern, loc_of_parsing f.loc)))
          ctx fields
      in
      let fields_names =
        List.map (fun ((name : ident), _, _) -> name.name) infos
      in
      match find_record_by_field_names ctx fields_names with
      | Some record_info ->
          let ctx, idx_fields =
            unify_record_pattern_fields_with_decl ctx record_info.record_fields
              infos
          in
          let fields =
            List.map2
              (fun (name, pattern, loc) field_idx ->
                { field_idx; name; pattern; loc })
              infos idx_fields
          in
          let ty =
            mk_ty (TTy_Defined { name = record_info.ty_decl.name; args = [] })
          in
          (ctx, { id = p.id; pattern_desc = TPat_Record { fields }; loc; ty })
      | None ->
          raise
            (Type_error
               ( Some loc,
                 Printf.sprintf
                   "cannot infer record type for fields {%s}: no matching \
                    record type"
                   (String.concat ", "
                      (List.map (fun ((name : ident), _, _) -> name.name) infos))
               )))
  | Parsing_ast.Pat_Constructor { name; value } ->
      let ctx, arg_opt =
        match value with
        | None -> (ctx, None)
        | Some p ->
            let ctx, tp = infer_pattern ctx p in
            (ctx, Some tp)
      in
      let ctx, ty, contructor =
        match find_constructor_by_name ctx name.name with
        | None ->
            raise
              (Type_error
                 ( Some (loc_of_parsing name.loc),
                   Printf.sprintf "unknown variant constructor '%s'" name.name
                 ))
        | Some { constructor = ctor; ty_decl } ->
            let ctx =
              match (ctor.arg, arg_opt) with
              | None, None -> ctx
              | None, Some _ ->
                  raise
                    (Type_error
                       ( Some (loc_of_parsing name.loc),
                         Printf.sprintf
                           "variant constructor '%s' takes no argument"
                           name.name ))
              | Some _, None ->
                  raise
                    (Type_error
                       ( Some (loc_of_parsing name.loc),
                         Printf.sprintf
                           "variant constructor '%s' expects an argument"
                           name.name ))
              | Some (Constr_ty t), Some pat ->
                  unify_into ~loc:pat.loc ctx pat.ty t
              | ( Some (Constr_record fields),
                  Some { pattern_desc = TPat_Record { fields = pat_fields }; _ }
                ) ->
                  let pat_infos =
                    List.map
                      (fun (f : pattern_record_field) ->
                        (f.name, f.pattern, f.loc))
                      pat_fields
                  in
                  let ctx, _ =
                    unify_record_pattern_fields_with_decl ctx fields pat_infos
                  in
                  ctx
              | Some (Constr_record _), Some _ ->
                  raise
                    (Type_error
                       ( Some (loc_of_parsing name.loc),
                         Printf.sprintf
                           "variant constructor '%s' expects a record pattern"
                           name.name ))
            in
            (ctx, mk_ty (TTy_Defined { name = ty_decl.name; args = [] }), ctor)
      in
      ( ctx,
        {
          id = p.id;
          pattern_desc =
            TPat_Constructor
              { tag = contructor.tag; ident = name.name; pattern = arg_opt };
          loc;
          ty;
        } )
  | Parsing_ast.Pat_Any ->
      (ctx, { id = p.id; pattern_desc = TPat_Any; loc; ty = mk_ty TTy_Any })

let rec infer_expr (ctx : infer_ctx) (e : Parsing_ast.expr) : infer_ctx * expr =
  let loc = loc_of_parsing e.loc in
  match e.expr_desc with
  | Parsing_ast.Exp_Constant c ->
      let const_desc, ct = constant_desc_of_parsing c.constant_desc in
      let ty = mk_ty (TTy_Constant ct) in
      ( ctx,
        {
          id = e.id;
          expr_desc =
            TExp_Constant { id = c.id; constant_desc = const_desc; loc };
          loc;
          ty;
        } )
  | Parsing_ast.Exp_Ident i ->
      let ctx, ty =
        if i.name = "_" then (ctx, mk_ty TTy_Any)
        else
          match TyEnv.lookup_opt i.name ctx.env with
          | Some s -> instantiate_scheme ctx s
          | None ->
              raise
                (Type_error
                   ( Some (loc_of_parsing i.loc),
                     Printf.sprintf "Unbound identifier '%s'" i.name ))
      in
      (ctx, { id = e.id; expr_desc = TExp_Ident (ident_of_parsing i); loc; ty })
  | Parsing_ast.Exp_Tuple { elements } ->
      let ctx, elems = List.fold_left_map infer_expr ctx elements in
      let ty = mk_ty (TTy_Tuple (List.map (fun (e : expr) -> e.ty) elems)) in
      (ctx, { id = e.id; expr_desc = TExp_Tuple { elements = elems }; loc; ty })
  | Parsing_ast.Exp_Record { fields } -> (
      let ctx, infos =
        List.fold_left_map
          (fun ctx (f : Parsing_ast.record_field) ->
            let ctx, tv = infer_expr ctx f.field_value in
            (ctx, (ident_of_parsing f.field_name, tv, loc_of_parsing f.loc)))
          ctx fields
      in
      let field_names =
        List.map (fun ((name : ident), _, _) -> name.name) infos
      in
      match find_record_by_field_names ctx field_names with
      | Some record_info ->
          let ctx, idx_fields =
            unify_record_expr_fields_with_decl ctx record_info.record_fields
              infos
          in
          let fields =
            List.map2
              (fun ((field_name : ident), field_value, loc) field_idx ->
                { id = field_name.id; field_name; field_idx; field_value; loc })
              infos idx_fields
          in
          let ty =
            mk_ty (TTy_Defined { name = record_info.ty_decl.name; args = [] })
          in
          (ctx, { id = e.id; expr_desc = TExp_Record { fields }; loc; ty })
      | None ->
          raise
            (Type_error
               ( Some (loc_of_parsing e.loc),
                 Printf.sprintf
                   "cannot infer record type for fields {%s}: no matching \
                    record type"
                   (String.concat ", "
                      (List.map (fun ((name : ident), _, _) -> name.name) infos))
               )))
  | Parsing_ast.Exp_VariantConstructor { name; arg } ->
      let name = ident_of_parsing name in
      let ctx, arg_expr, ty, constructor =
        match find_constructor_by_name ctx name.name with
        | None ->
            raise
              (Type_error
                 ( Some name.loc,
                   Printf.sprintf "unknown variant constructor '%s'" name.name
                 ))
        | Some { constructor = ctor; ty_decl } -> (
            let variant_ty =
              mk_ty (TTy_Defined { name = ty_decl.name; args = [] })
            in
            match (ctor.arg, arg) with
            | None, None -> (ctx, None, variant_ty, ctor)
            | Some (Constr_ty t), None ->
                (ctx, None, mk_ty (TTy_Arrow (t, variant_ty)), ctor)
            | Some (Constr_record _), None ->
                (ctx, None, mk_ty (TTy_Arrow (variant_ty, variant_ty)), ctor)
            | None, Some _ ->
                raise
                  (Type_error
                     ( Some name.loc,
                       Printf.sprintf
                         "variant constructor '%s' takes no argument" name.name
                     ))
            | Some (Constr_ty t), Some a ->
                let ctx, a = infer_expr ctx a in
                let ctx = unify_into ~loc:a.loc ctx a.ty t in
                (ctx, Some a, variant_ty, ctor)
            | Some (Constr_record fields), Some a -> (
                match a.expr_desc with
                | Parsing_ast.Exp_Record { fields = fields' } ->
                    let ctx, infos =
                      List.fold_left_map
                        (fun ctx (f : Parsing_ast.record_field) ->
                          let ctx, tv = infer_expr ctx f.field_value in
                          ( ctx,
                            ( ident_of_parsing f.field_name,
                              tv,
                              loc_of_parsing f.loc ) ))
                        ctx fields'
                    in
                    let ctx, idx_fields =
                      unify_record_expr_fields_with_decl ctx fields infos
                    in
                    let typed_fields =
                      List.map2
                        (fun ((field_name : ident), field_value, loc) field_idx
                           ->
                          {
                            id = field_name.id;
                            field_name;
                            field_idx;
                            field_value;
                            loc;
                          })
                        infos idx_fields
                    in
                    let record_expr =
                      {
                        id = a.id;
                        expr_desc = TExp_Record { fields = typed_fields };
                        loc = loc_of_parsing a.loc;
                        ty = variant_ty;
                      }
                    in
                    (ctx, Some record_expr, variant_ty, ctor)
                | _ ->
                    raise
                      (Type_error
                         ( Some name.loc,
                           Printf.sprintf
                             "variant constructor '%s' expects a record \
                              argument"
                             name.name ))))
      in
      ( ctx,
        {
          id = e.id;
          expr_desc =
            TExp_VariantConstructor
              { tag = constructor.tag; name; arg = arg_expr };
          loc;
          ty;
        } )
  | Parsing_ast.Exp_Lambda l ->
      let old_ctx = ctx in
      let ctx, params_arg_tys =
        List.fold_left_map
          (fun ctx (p : Parsing_ast.param) ->
            let param_loc = loc_of_parsing p.loc in
            let ctx, pty =
              match p.param_ty with
              | Some t -> ty_of_parsing ctx t
              | None -> fresh_ty ctx
            in
            let ctx, pp = infer_pattern ctx p.pattern in
            let ctx = unify_into ~loc:pp.loc ctx pp.ty pty in
            let pty = apply_ty ctx pty in
            let tp = { pattern = pp; param_ty = Some pty; loc = param_loc } in
            (ctx, (tp, pty)))
          ctx l.params
      in
      let params, arg_tys = List.split params_arg_tys in
      let ctx, body = infer_expr ctx l.body in
      let ctx, ret_ty =
        match l.ret_ty with
        | None -> (ctx, apply_ty ctx body.ty)
        | Some t ->
            let ctx, expected = ty_of_parsing ctx t in
            let ctx = unify_into ~loc:body.loc ctx body.ty expected in
            (ctx, apply_ty ctx expected)
      in
      let resolved_ret_ty = Some (apply_ty ctx ret_ty) in
      let lambda =
        {
          params = List.map (apply_param_ty ctx) params;
          body;
          ret_ty = resolved_ret_ty;
          loc;
        }
      in
      let ty = arrow_ty_of_params (List.map (apply_ty ctx) arg_tys) ret_ty in
      let new_ctx =
        {
          ctx with
          env = old_ctx.env;
          (*  We restore the old scope variables, it avoid the local ones escaping,
              but the substitution stays in order to substitute them later *)
          return_ty = old_ctx.return_ty;
          break_ty = old_ctx.break_ty;
        }
      in
      (new_ctx, { id = e.id; expr_desc = TExp_Lambda lambda; loc; ty })
  | Parsing_ast.Exp_Apply { closure_fun; args } ->
      let ctx, fn = infer_expr ctx closure_fun in
      let ctx, args = List.fold_left_map infer_expr ctx args in
      let ctx, fn_ty =
        match apply_ty ctx fn.ty with
        | { ty_desc = TTy_Arrow _ } as fn_ty -> (ctx, fn_ty)
        | { ty_desc = TTy_Var _ } ->
            let ctx, params =
              List.fold_left_map
                (fun ctx _ ->
                  let ctx, ty = fresh_ty ctx in
                  (ctx, ty))
                ctx args
            in
            let ctx, ret_ty = fresh_ty ctx in
            let fn_ty = arrow_ty_of_params params ret_ty in
            let ctx = unify_into ~loc:fn.loc ctx fn.ty fn_ty in
            (ctx, apply_ty ctx fn_ty)
        | _ -> (
            match fn.expr_desc with
            | TExp_VariantConstructor { name; _ } ->
                raise
                  (Type_error
                     ( Some name.loc,
                       Printf.sprintf
                         "variant constructor '%s' is not a function" name.name
                     ))
            | _ ->
                raise
                  (Type_error
                     ( Some fn.loc,
                       Printf.sprintf "expected function type, got %s"
                         (Pretty_print_code.string_of_ty (apply_ty ctx fn.ty))
                     )))
      in
      let fn = { fn with ty = fn_ty } in
      let rec infer_arguments (ctx : infer_ctx) (remaining_ty : ty)
          (args : expr list) (consumed : int) : infer_ctx * ty =
        match (remaining_ty.ty_desc, args) with
        | TTy_Arrow (param, ret), arg :: rest_args ->
            let ctx = unify_into ~loc:arg.loc ctx param arg.ty in
            infer_arguments ctx ret rest_args (consumed + 1)
        | _, [] -> (ctx, apply_ty ctx remaining_ty)
        | _, _ ->
            (* remaining_ty is not an arrow here, so all arrows are consumed *)
            raise
              (Type_error
                 ( Some (loc_of_parsing e.loc),
                   Printf.sprintf "function expects %d argument(s), got %d"
                     consumed
                     (consumed + List.length args) ))
      in
      let ctx, ty = infer_arguments ctx fn_ty args 0 in
      ( ctx,
        {
          id = e.id;
          loc = loc_of_parsing e.loc;
          expr_desc =
            TExp_Apply
              { closure_fun = fn; args = List.map (apply_expr_ty ctx) args };
          ty;
        } )
  | Parsing_ast.Exp_Let ldef ->
      let ctx, tdef = infer_letdef ctx ldef in
      ( ctx,
        {
          id = e.id;
          expr_desc = TExp_Let tdef;
          loc;
          ty = mk_ty (TTy_Constant TTy_Unit);
        } )
  | Parsing_ast.Exp_If { condition; then_branch; else_branch } ->
      let ctx, cond = infer_expr ctx condition in
      let ctx =
        unify_into ~loc:cond.loc ctx cond.ty (mk_ty (TTy_Constant TTy_Bool))
      in
      let ctx, then_branch = infer_expr ctx then_branch in
      let ctx, else_branch, out_ty =
        match else_branch with
        | None ->
            let ty = mk_ty (TTy_Constant TTy_Unit) in
            let ctx = unify_into ~loc:then_branch.loc ctx then_branch.ty ty in
            (ctx, None, ty)
        | Some e ->
            let ctx, e = infer_expr ctx e in
            let ctx = unify_into ~loc:e.loc ctx then_branch.ty e.ty in
            (ctx, Some e, apply_ty ctx then_branch.ty)
      in
      ( ctx,
        {
          id = e.id;
          expr_desc = TExp_If { condition = cond; then_branch; else_branch };
          loc;
          ty = out_ty;
        } )
  | Parsing_ast.Exp_While { condition; body } ->
      let ctx, cond = infer_expr ctx condition in
      let ctx =
        unify_into ~loc:cond.loc ctx cond.ty (mk_ty (TTy_Constant TTy_Bool))
      in
      let ctx, body = infer_expr ctx body in
      let ty = mk_ty (TTy_Constant TTy_Unit) in
      ( ctx,
        {
          id = e.id;
          expr_desc = TExp_While { condition = cond; body };
          loc;
          ty;
        } )
  | Parsing_ast.Exp_Loop { condition } ->
      let ctx, body = infer_expr ctx condition in
      let ctx, ty = fresh_ty ctx in
      (ctx, { id = e.id; expr_desc = TExp_Loop { expr = body }; loc; ty })
  | Parsing_ast.Exp_Array { element_ty; elements; size } ->
      let ctx, element_ty = ty_of_parsing ctx element_ty in
      let ctx, elements = List.fold_left_map infer_expr ctx elements in
      let ctx, size = infer_expr ctx size in
      let ctx =
        unify_into ~loc:size.loc ctx size.ty (mk_ty (TTy_Constant TTy_Int64))
      in
      let ty = mk_ty (TTy_Array element_ty) in
      ( ctx,
        {
          id = e.id;
          expr_desc = TExp_Array { element_ty; elements; size };
          loc;
          ty;
        } )
  | Parsing_ast.Exp_FieldSet { record; field_name; value } ->
      let ctx, record = infer_expr ctx record in
      let ctx, value = infer_expr ctx value in
      let ctx, expr' =
        match find_record_by_field_names ctx [ field_name.name ] with
        | Some ty_record_info -> (
            let ctx =
              unify_into ~loc:record.loc ctx record.ty
                (mk_ty
                   (TTy_Defined
                      { name = ty_record_info.ty_decl.name; args = [] }))
            in
            match
              List.find_opt
                (fun (field : record_field_decl) ->
                  field.field_name.name = field_name.name)
                ty_record_info.record_fields
            with
            | Some field -> (
                match field.field_mut with
                | TImmutable ->
                    raise
                      (Type_error
                         ( Some (loc_of_parsing field_name.loc),
                           Printf.sprintf "field '%s' is immutable"
                             field_name.name ))
                | TMutable ->
                    let ctx =
                      unify_into ~loc:value.loc ctx value.ty field.field_ty
                    in
                    ( ctx,
                      {
                        id = e.id;
                        expr_desc =
                          TExp_FieldSet
                            {
                              record;
                              field_name = ident_of_parsing field_name;
                              field_idx = field.field_idx;
                              value;
                            };
                        loc;
                        ty = mk_ty (TTy_Constant TTy_Unit);
                      } ))
            | None ->
                raise
                  (Type_error
                     ( Some (loc_of_parsing field_name.loc),
                       Printf.sprintf "field '%s' is not found" field_name.name
                     )))
        | None ->
            raise
              (Type_error
                 ( Some (loc_of_parsing field_name.loc),
                   Printf.sprintf "no record has field_name '%s'"
                     field_name.name ))
      in
      (ctx, expr')
  | Parsing_ast.Exp_Break { value } ->
      let ctx, e_opt =
        match value with
        | None -> (ctx, None)
        | Some e ->
            let ctx, e = infer_expr ctx e in
            (ctx, Some e)
      in
      let ty = mk_ty (TTy_Constant TTy_Unit) in
      (ctx, { id = e.id; expr_desc = TExp_Break { expr_opt = e_opt }; loc; ty })
  | Parsing_ast.Exp_Continue ->
      let ty = mk_ty (TTy_Constant TTy_Unit) in
      (ctx, { id = e.id; expr_desc = TExp_Continue; loc; ty })
  | Parsing_ast.Exp_Return { value } ->
      let ctx, e_opt =
        match value with
        | None -> (ctx, None)
        | Some e ->
            let ctx, e = infer_expr ctx e in
            (ctx, Some e)
      in
      let ty = mk_ty (TTy_Constant TTy_Unit) in
      (ctx, { id = e.id; expr_desc = TExp_Return { expr_opt = e_opt }; loc; ty })
  | Parsing_ast.Exp_Seq { exprs } ->
      let ctx, exprs = List.fold_left_map infer_expr ctx exprs in
      let ty =
        match List.rev exprs with
        | [] -> mk_ty (TTy_Constant TTy_Unit)
        | last :: _ -> last.ty
      in
      (ctx, { id = e.id; expr_desc = TExp_Seq { exprs }; loc; ty })
  | Parsing_ast.Exp_Match { expr = target; cases } ->
      let ctx, target = infer_expr ctx target in
      let ctx, out_ty = fresh_ty ctx in
      let ctx, cases =
        List.fold_left_map
          (fun ctx (c : Parsing_ast.pattern_case) ->
            let old_ctx = ctx in
            let ctx, pat = infer_pattern ctx c.pattern in
            let ctx = unify_into ~loc:pat.loc ctx target.ty pat.ty in
            let ctx, when_condition =
              match c.when_condition with
              | None -> (ctx, None)
              | Some w ->
                  let ctx, tw = infer_expr ctx w in
                  let ctx =
                    unify_into ~loc:tw.loc ctx tw.ty
                      (mk_ty (TTy_Constant TTy_Bool))
                  in
                  (ctx, Some tw)
            in
            let ctx, body = infer_expr ctx c.body in
            let ctx = unify_into ~loc:body.loc ctx body.ty out_ty in
            let tc =
              {
                id = c.id;
                pattern = pat;
                when_condition;
                body;
                loc = loc_of_parsing c.loc;
                ty = apply_ty ctx body.ty;
              }
            in
            let env = old_ctx.env in
            (* we restore the env everytime after typing the body of the pattern-case *)
            ({ ctx with env }, tc))
          ctx cases
      in
      ( ctx,
        {
          id = e.id;
          expr_desc = TExp_Match { expr = target; cases };
          loc;
          ty = apply_ty ctx out_ty;
        } )
  | Parsing_ast.Exp_Field { record; field_name } ->
      let ctx, record = infer_expr ctx record in
      let ctx, field_ty, field_idx =
        match find_record_by_field_names ctx [ field_name.name ] with
        | Some ty_record_info -> (
            let ctx =
              unify_into ~loc:record.loc ctx record.ty
                (mk_ty
                   (TTy_Defined
                      { name = ty_record_info.ty_decl.name; args = [] }))
            in
            match
              List.find_opt
                (fun (field : record_field_decl) ->
                  field.field_name.name = field_name.name)
                ty_record_info.record_fields
            with
            | Some field -> (ctx, field.field_ty, field.field_idx)
            | None ->
                raise
                  (Type_error
                     ( Some (loc_of_parsing field_name.loc),
                       Printf.sprintf "field '%s' is not found" field_name.name
                     )))
        | None ->
            raise
              (Type_error
                 ( Some (loc_of_parsing field_name.loc),
                   Printf.sprintf "no record has field_name '%s'"
                     field_name.name ))
      in
      ( ctx,
        {
          id = e.id;
          expr_desc =
            TExp_Field
              { record; field_name = ident_of_parsing field_name; field_idx };
          loc;
          ty = field_ty;
        } )

and infer_letdef (ctx : infer_ctx) (ldef : Parsing_ast.letdef) :
    infer_ctx * letdef =
  let loc = loc_of_parsing ldef.loc in
  let rec_flag =
    match ldef.rec_flag with
    | Parsing_ast.Recursive -> TRecursive
    | Parsing_ast.NonRecursive -> TNonRecursive
  in
  let ctx, value =
    match (rec_flag, ldef.pattern.node) with
    | TRecursive, Parsing_ast.Pat_Ident name ->
        let ctx, fn_ty = fresh_ty ctx in
        let ctx =
          {
            ctx with
            env = TyEnv.extend name.name { vars = []; body = fn_ty } ctx.env;
          }
          (* vars is empty because function will be monomorphic inside its own body.
          unless we want to extend it for polymorphic recursion. *)
        in
        let ctx, value = infer_expr ctx ldef.value in
        let ctx = unify_into ~loc:value.loc ctx fn_ty value.ty in
        (ctx, value)
    | _ -> infer_expr ctx ldef.value
  in
  let ctx, pattern = infer_pattern ctx ldef.pattern in
  let ctx = unify_into ~loc:pattern.loc ctx pattern.ty value.ty in
  let ctx, ty_opt =
    match ldef.ty_annot with
    | None -> (ctx, None)
    | Some t ->
        let ctx, expected = ty_of_parsing ctx t in
        let ctx = unify_into ~loc:value.loc ctx expected value.ty in
        (ctx, Some (apply_ty ctx expected))
  in
  let let_kind =
    match ldef.let_kind with
    | Parsing_ast.LetVal -> TLetVal
    | Parsing_ast.LetFun -> TLetFun
  in
  let ctx =
    match pattern.pattern_desc with
    | TPat_Ident name ->
        let value_ty = apply_ty ctx value.ty in
        {
          ctx with
          env =
            TyEnv.extend name.name
              {
                vars = ty_vars value_ty |> List.sort_uniq Int.compare;
                body = value_ty;
              }
              ctx.env;
        }
    | _ -> ctx
  in
  (ctx, { let_kind; rec_flag; pattern; value; ty_opt; loc })

let rec infer_structure_item (ctx : infer_ctx) (si : Parsing_ast.structure_item)
    : infer_ctx * structure_item =
  let loc = loc_of_parsing si.loc in
  match si.structure_item_desc with
  | Parsing_ast.Str_External { fname; ty; external_fn } ->
      let ctx, ty = ty_of_parsing ctx ty in
      let external_fn = external_fn_of_parsing external_fn in
      let ctx =
        {
          ctx with
          env =
            TyEnv.extend fname.name
              { vars = ty_vars ty |> List.sort_uniq Int.compare; body = ty }
              ctx.env;
        }
      in
      ( ctx,
        {
          id = si.id;
          structure_item_desc =
            TStr_External { fname = ident_of_parsing fname; ty; external_fn };
          loc;
        } )
  | Parsing_ast.Str_Let ldef ->
      let ctx, ldef = infer_letdef ctx ldef in
      (ctx, { id = si.id; structure_item_desc = TStr_Let ldef; loc })
  | Parsing_ast.Str_Type td ->
      let ctx, td = ty_decl_of_parsing ctx td in
      let ctx = register_ty_decl ctx td in
      (ctx, { id = si.id; structure_item_desc = TStr_Type td; loc })
  | Parsing_ast.Str_ModuleStructure ms ->
      let ctx, ms = infer_module_structure ctx ms in
      (ctx, { id = si.id; structure_item_desc = TStr_ModuleStructure ms; loc })
  | Parsing_ast.Str_ModuleSignature ms ->
      let ctx, ms = module_signature_of_parsing ctx ms in
      (ctx, { id = si.id; structure_item_desc = TStr_ModuleSignature ms; loc })

and infer_module_structure (ctx : infer_ctx) (ms : Parsing_ast.module_structure)
    : infer_ctx * module_structure =
  let loc = loc_of_parsing ms.loc in
  let ctx, structure_items =
    List.fold_left_map infer_structure_item ctx ms.structure_items
  in
  (ctx, { id = ms.id; name = ident_of_parsing ms.name; structure_items; loc })

let infer_program (program : Parsing_ast.module_structure) :
    infer_ctx * module_structure =
  let ctx, ms = infer_module_structure empty_ctx program in
  let resolve _ ty =
    (* Post-typing pass: walk the entire AST and apply the final substitution,
     replacing all remaining [TTy_Var] unification variables that is
     resolved but not applied to the AST before *)
    Subst.apply ctx.subst ty
  in
  let t = Ast_transformer.{ identity_transformer with ty = resolve } in
  let ms = t.module_structure t ms in
  (ctx, ms)
