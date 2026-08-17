open Syli_parsing.Ast
open Typed_ast
open Env
open Infer_helpers
open Parse_ty
open Ty
module Parsing_ast = Syli_parsing.Ast

let apply_expr_ty (ctx : infer_ctx) (e : expr) : expr =
  { e with ty = apply_ty ctx e.ty }

let apply_param_ty (ctx : infer_ctx) (p : param) : param =
  { p with param_ty = Option.map (apply_ty ctx) p.param_ty }

let unify_record_expr_fields_with_decl (ctx : infer_ctx)
    (decl_fields : record_field_decl list) (fields : record_field list) :
    infer_ctx =
  let find_decl_field name =
    List.find_opt
      (fun (decl_field : record_field_decl) ->
        decl_field.field_name.name = name)
      decl_fields
  in
  List.fold_left
    (fun ctx (f : record_field) ->
      match find_decl_field f.field_name.name with
      | None ->
          raise
            (Type_error
               (Printf.sprintf "unknown record field '%s'" f.field_name.name))
      | Some decl_field -> unify_into ctx f.field_value.ty decl_field.field_ty)
    ctx fields

let unify_record_pattern_fields_with_decl (ctx : infer_ctx)
    (decl_fields : record_field_decl list) (fields : pattern_record_field list)
    : infer_ctx =
  let find_decl_field name =
    List.find_opt
      (fun (decl_field : record_field_decl) ->
        decl_field.field_name.name = name)
      decl_fields
  in
  List.fold_left
    (fun ctx (f : pattern_record_field) ->
      match find_decl_field f.name.name with
      | None ->
          raise
            (Type_error (Printf.sprintf "unknown record field '%s'" f.name.name))
      | Some decl_field -> (
          match f.pattern with
          | None -> ctx
          | Some p -> unify_into ctx p.ty decl_field.field_ty))
    ctx fields

let rec infer_pattern (ctx : infer_ctx) (p : Parsing_ast.pattern) :
    infer_ctx * pattern =
  let loc = loc_of_parsing p.loc in
  match p.node with
  | Parsing_ast.Pat_Unit ->
      let ty = mk_ty (Ty_Constant Ty_Unit) in
      (ctx, { id = p.id; pattern_desc = TPat_Unit; loc; ty })
  | Parsing_ast.Pat_BoolLit s ->
      let ty = mk_ty (Ty_Constant Ty_Bool) in
      (ctx, { id = p.id; pattern_desc = TPat_BoolLit s; loc; ty })
  | Parsing_ast.Pat_IntLit s ->
      let ty = mk_ty (Ty_Constant Ty_Int64) in
      (ctx, { id = p.id; pattern_desc = TPat_IntLit s; loc; ty })
  | Parsing_ast.Pat_CharLit s ->
      let ty = mk_ty (Ty_Constant Ty_CharLit) in
      (ctx, { id = p.id; pattern_desc = TPat_CharLit s; loc; ty })
  | Parsing_ast.Pat_StringLit s ->
      let ty = mk_ty (Ty_Constant Ty_StringLit) in
      (ctx, { id = p.id; pattern_desc = TPat_StringLit s; loc; ty })
  | Parsing_ast.Pat_FloatLit s ->
      let ty = mk_ty (Ty_Constant Ty_Double) in
      (ctx, { id = p.id; pattern_desc = TPat_FloatLit s; loc; ty })
  | Parsing_ast.Pat_Ident name ->
      if name.name = "_" then
        (ctx, { id = p.id; pattern_desc = TPat_Any; loc; ty = mk_ty Ty_Any })
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
      let ty = mk_ty (Ty_Tuple tys) in
      ( ctx,
        { id = p.id; pattern_desc = TPat_Tuple { elements = pats }; loc; ty } )
  | Parsing_ast.Pat_Record { fields } ->
      let ctx, typed_fields =
        List.fold_left_map
          (fun ctx (f : Parsing_ast.pattern_record_field) ->
            match f.pattern with
            | None ->
                (ctx, { name = ident_of_parsing f.name; pattern = None; loc })
            | Some p ->
                let ctx, tp = infer_pattern ctx p in
                (ctx, { name = ident_of_parsing f.name; pattern = Some tp; loc }))
          ctx fields
      in
      let ctx, ty = fresh_ty ctx in
      ( ctx,
        {
          id = p.id;
          pattern_desc = TPat_Record { fields = typed_fields };
          loc;
          ty;
        } )
  | Parsing_ast.Pat_Constructor { name; pattern } ->
      let ctx, arg_opt =
        match pattern with
        | None -> (ctx, None)
        | Some p ->
            let ctx, tp = infer_pattern ctx p in
            (ctx, Some tp)
      in
      let ctx, ty =
        match find_constructor_by_name ctx name.name with
        | None ->
            raise
              (Type_error
                 (Printf.sprintf "unknown variant constructor '%s'" name.name))
        | Some { constructor = ctor; ty_decl } ->
            let ctx =
              match (ctor.arg, arg_opt) with
              | None, None -> ctx
              | None, Some _ ->
                  raise
                    (Type_error
                       (Printf.sprintf
                          "variant constructor '%s' takes no argument" name.name))
              | Some _, None ->
                  raise
                    (Type_error
                       (Printf.sprintf
                          "variant constructor '%s' expects an argument"
                          name.name))
              | Some (Constr_ty t), Some pat -> unify_into ctx pat.ty t
              | ( Some (Constr_record fields),
                  Some { pattern_desc = TPat_Record { fields = pat_fields }; _ }
                ) ->
                  unify_record_pattern_fields_with_decl ctx fields pat_fields
              | Some (Constr_record _), Some _ ->
                  raise
                    (Type_error
                       (Printf.sprintf
                          "variant constructor '%s' expects a record pattern"
                          name.name))
            in
            (ctx, mk_ty (Ty_Defined { name = ty_decl.name; args = [] }))
      in
      ( ctx,
        {
          id = p.id;
          pattern_desc =
            TPat_Constructor { ident = name.name; pattern = arg_opt };
          loc;
          ty;
        } )
  | Parsing_ast.Pat_Any ->
      (ctx, { id = p.id; pattern_desc = TPat_Any; loc; ty = mk_ty Ty_Any })

let rec infer_expr (ctx : infer_ctx) (e : Parsing_ast.expr) : infer_ctx * expr =
  let loc = loc_of_parsing e.loc in
  match e.expr_desc with
  | Parsing_ast.Exp_Constant c ->
      let const_desc, ct = constant_desc_of_parsing c.constant_desc in
      let ty = mk_ty (Ty_Constant ct) in
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
        if i.name = "_" then (ctx, mk_ty Ty_Any)
        else
          match TyEnv.lookup_opt i.name ctx.env with
          | Some s -> instantiate_scheme ctx s
          | None ->
              let ctx, t = fresh_ty ctx in
              (ctx, t)
      in
      ( ctx,
        {
          id = e.id;
          expr_desc = TExp_Ident { name = i.name; id = i.id; path = []; loc };
          loc;
          ty;
        } )
  | Parsing_ast.Exp_Tuple { elements } ->
      let ctx, elems = List.fold_left_map infer_expr ctx elements in
      let ty = mk_ty (Ty_Tuple (List.map (fun (e : expr) -> e.ty) elems)) in
      (ctx, { id = e.id; expr_desc = TExp_Tuple { elements = elems }; loc; ty })
  | Parsing_ast.Exp_Record { fields } ->
      let ctx, fields =
        List.fold_left_map
          (fun ctx (f : Parsing_ast.record_field) ->
            let ctx, tv = infer_expr ctx f.field_value in
            ( ctx,
              {
                id = f.id;
                field_name =
                  {
                    name = f.field_name.name;
                    id = f.field_name.id;
                    path = [];
                    loc = loc_of_parsing f.field_name.loc;
                  };
                field_value = tv;
                loc = loc_of_parsing f.loc;
              } ))
          ctx fields
      in
      let field_names = List.map (fun field -> field.field_name.name) fields in
      let ctx, ty =
        match find_record_by_field_names ctx field_names with
        | Some record_info ->
            let ctx =
              unify_record_expr_fields_with_decl ctx record_info.record_fields
                fields
            in
            ( ctx,
              mk_ty (Ty_Defined { name = record_info.ty_decl.name; args = [] })
            )
        | None ->
            raise
              (Type_error
                 (Printf.sprintf
                    "cannot infer record type for fields {%s}: no matching \
                     record type"
                    (String.concat ", "
                       (List.map
                          (fun (f : record_field) -> f.field_name.name)
                          fields))))
      in
      (ctx, { id = e.id; expr_desc = TExp_Record { fields }; loc; ty })
  | Parsing_ast.Exp_VariantConstructor { name; arg } ->
      let name =
        {
          name = name.name;
          id = name.id;
          path = [];
          loc = loc_of_parsing name.loc;
        }
      in
      let ctx, args, ty =
        match find_constructor_by_name ctx name.name with
        | None ->
            raise
              (Type_error
                 (Printf.sprintf "unknown variant constructor '%s'" name.name))
        | Some { constructor = ctor; ty_decl } -> (
            let variant_ty =
              mk_ty (Ty_Defined { name = ty_decl.name; args = [] })
            in
            match (ctor.arg, arg) with
            | None, None -> (ctx, None, variant_ty)
            | Some (Constr_ty t), None ->
                (ctx, None, mk_ty (Ty_Arrow ([ t ], variant_ty)))
            | Some (Constr_record _), None ->
                (ctx, None, mk_ty (Ty_Arrow ([ variant_ty ], variant_ty)))
            | None, Some _ ->
                raise
                  (Type_error
                     (Printf.sprintf
                        "variant constructor '%s' takes no argument" name.name))
            | Some (Constr_ty t), Some a ->
                let ctx, a = infer_expr ctx a in
                let ctx = unify_into ctx a.ty t in
                (ctx, Some a, variant_ty)
            | Some (Constr_record fields), Some a -> (
                match a.expr_desc with
                | Parsing_ast.Exp_Record { fields = fields' } ->
                    let ctx, typed_fields =
                      List.fold_left_map
                        (fun ctx (f : Parsing_ast.record_field) ->
                          let ctx, tv = infer_expr ctx f.field_value in
                          ( ctx,
                            {
                              id = f.id;
                              field_name =
                                {
                                  name = f.field_name.name;
                                  id = f.field_name.id;
                                  path = [];
                                  loc = loc_of_parsing f.field_name.loc;
                                };
                              field_value = tv;
                              loc = loc_of_parsing f.loc;
                            } ))
                        ctx fields'
                    in
                    let ctx =
                      unify_record_expr_fields_with_decl ctx fields typed_fields
                    in
                    let record_expr =
                      {
                        id = a.id;
                        expr_desc = TExp_Record { fields = typed_fields };
                        loc = loc_of_parsing a.loc;
                        ty = variant_ty;
                      }
                    in
                    (ctx, Some record_expr, variant_ty)
                | _ ->
                    raise
                      (Type_error
                         (Printf.sprintf
                            "variant constructor '%s' expects a record argument"
                            name.name))))
      in
      ( ctx,
        {
          id = e.id;
          expr_desc = TExp_VariantConstructor { name; args };
          loc;
          ty;
        } )
  | Parsing_ast.Exp_ArrayCreate { element_ty; size } ->
      let ctx, element_ty = ty_of_parsing ctx element_ty in
      let ctx, size = infer_expr ctx size in
      let ty = mk_ty (Ty_Array element_ty) in
      ( ctx,
        {
          id = e.id;
          expr_desc = TExp_ArrayCreate { element_ty; size };
          loc;
          ty;
        } )
  | Parsing_ast.Exp_ArrayLength { arr } ->
      let ctx, arr' = infer_expr ctx arr in
      let ty = mk_ty (Ty_Constant Ty_Int64) in
      (ctx, { id = e.id; expr_desc = TExp_ArrayLength { arr = arr' }; loc; ty })
  | Parsing_ast.Exp_ArrayGet { arr; idx } ->
      let ctx, arr' = infer_expr ctx arr in
      let ctx, idx = infer_expr ctx idx in
      let ctx, ty = fresh_ty ctx in
      ( ctx,
        { id = e.id; expr_desc = TExp_ArrayGet { arr = arr'; idx }; loc; ty } )
  | Parsing_ast.Exp_ArraySet { arr; idx; value } ->
      let ctx, arr' = infer_expr ctx arr in
      let ctx, idx = infer_expr ctx idx in
      let ctx, value = infer_expr ctx value in
      let ty = mk_ty (Ty_Constant Ty_Unit) in
      ( ctx,
        {
          id = e.id;
          expr_desc = TExp_ArraySet { arr = arr'; idx; value };
          loc;
          ty;
        } )
  | Parsing_ast.Exp_UnOp { op; value } ->
      let ctx, inner = infer_expr ctx value in
      let top = unop_of_parsing op in
      let ty =
        match op with
        | Parsing_ast.Unop_Logical _ -> mk_ty (Ty_Constant Ty_Bool)
        | Parsing_ast.Unop_Arithmetic _ | Parsing_ast.Unop_Bitwise _ -> inner.ty
      in
      ( ctx,
        {
          id = e.id;
          expr_desc = TExp_UnOp { op = top; value = inner };
          loc;
          ty;
        } )
  | Parsing_ast.Exp_Ref { value } ->
      let ctx, inner = infer_expr ctx value in
      let ty = mk_ty (Ty_Ref inner.ty) in
      (ctx, { id = e.id; expr_desc = TExp_Ref { value = inner }; loc; ty })
  | Parsing_ast.Exp_Deref { value } ->
      let ctx, inner = infer_expr ctx value in
      let ctx, elem_ty = fresh_ty ctx in
      let ref_ty = mk_ty (Ty_Ref elem_ty) in
      let ctx = unify_into ctx inner.ty ref_ty in
      ( ctx,
        {
          id = e.id;
          expr_desc = TExp_Deref { value = inner };
          loc;
          ty = apply_ty ctx elem_ty;
        } )
  | Parsing_ast.Exp_BinOp { op; lvalue; rvalue } ->
      let ctx, lhs = infer_expr ctx lvalue in
      let ctx, rhs = infer_expr ctx rvalue in
      let top = binop_of_parsing op in
      let ctx, ty =
        match op with
        | Parsing_ast.Binop_Logical _ ->
            let bool_ty = mk_ty (Ty_Constant Ty_Bool) in
            let ctx = unify_into ctx lhs.ty bool_ty in
            let ctx = unify_into ctx rhs.ty bool_ty in
            (ctx, bool_ty)
        | Parsing_ast.Binop_Arithmetic _ ->
            let ctx = unify_into ctx lhs.ty rhs.ty in
            let lhs_ty = apply_ty ctx lhs.ty in
            ensure_numeric_ty lhs_ty;
            (ctx, lhs_ty)
        | Parsing_ast.Binop_Bitwise _ ->
            let ctx = unify_into ctx lhs.ty rhs.ty in
            let lhs_ty = apply_ty ctx lhs.ty in
            ensure_integer_ty lhs_ty;
            (ctx, lhs_ty)
        | Parsing_ast.Binop_Comparison _ ->
            let ctx = unify_into ctx lhs.ty rhs.ty in
            let unified = apply_ty ctx lhs.ty in
            (match unified.ty_desc with
            | Ty_Constant _ | Ty_Var _ | Ty_Any -> ()
            | _ ->
                raise
                  (Type_error
                     (Printf.sprintf
                        "comparison expects scalar/primitive operands, got %s"
                        (string_of_ty unified))));
            (ctx, mk_ty (Ty_Constant Ty_Bool))
      in
      ( ctx,
        {
          id = e.id;
          expr_desc = TExp_BinOp { op = top; lvalue = lhs; rvalue = rhs };
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
            let ctx = unify_into ctx pp.ty pty in
            let pty = apply_ty ctx pty in
            let tp =
              {
                pattern = pp;
                mut_flag = p.mut_flag;
                param_ty = Some pty;
                loc = param_loc;
              }
            in
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
            let ctx = unify_into ctx body.ty expected in
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
      let ty = mk_ty @@ Ty_Arrow (List.map (apply_ty ctx) arg_tys, ret_ty) in
      let new_ctx =
        {
          ctx with
          env = old_ctx.env;
          (*  We restore the old scope variables, it avoid local ones escaping,
            but the substitution stays in order to substitute them later *)
          return_ty = old_ctx.return_ty;
          break_ty = old_ctx.break_ty;
        }
      in
      (new_ctx, { id = e.id; expr_desc = TExp_Lambda lambda; loc; ty })
  | Parsing_ast.Exp_Apply { closure_fun; args } -> (
      let ctx, fn = infer_expr ctx closure_fun in
      let ctx, args = List.fold_left_map infer_expr ctx args in
      let ctx, fn_ty =
        match apply_ty ctx fn.ty with
        | { ty_desc = Ty_Arrow _ } as fn_ty -> (ctx, fn_ty)
        | { ty_desc = Ty_Var _ } ->
            let ctx, params =
              List.fold_left_map
                (fun ctx _ ->
                  let ctx, ty = fresh_ty ctx in
                  (ctx, ty))
                ctx args
            in
            let ctx, ret_ty = fresh_ty ctx in
            let fn_ty = mk_ty (Ty_Arrow (params, ret_ty)) in
            let ctx = unify_into ctx fn.ty fn_ty in
            (ctx, apply_ty ctx fn_ty)
        | _ -> (
            match fn.expr_desc with
            | TExp_VariantConstructor { name; _ } ->
                raise
                  (Type_error
                     (Printf.sprintf
                        "variant constructor '%s' is not a function" name.name))
            | _ ->
                raise
                  (Type_error
                     (Printf.sprintf "expected function type, got %s"
                        (string_of_ty (apply_ty ctx fn.ty)))))
      in
      let fn = { fn with ty = fn_ty } in
      let fn_params, fn_ret =
        match fn_ty.ty_desc with
        | Ty_Arrow (params, ret) -> (params, ret)
        | _ ->
            raise
              (Type_error "internal error: unification didn't produce arrow")
      in
      let matched_fn, matched_arg, rest_fn, rest_arg =
        matching_param_to_arg fn_params args
      in
      match (rest_fn, rest_arg) with
      | [], [] ->
          let ctx =
            List.fold_left2
              (fun ctx param (arg : Typed_ast.expr) ->
                unify_into ctx param arg.ty)
              ctx matched_fn matched_arg
          in
          ( ctx,
            {
              id = e.id;
              loc = loc_of_parsing e.loc;
              expr_desc =
                TExp_Apply
                  { closure_fun = fn; args = List.map (apply_expr_ty ctx) args };
              ty = apply_ty ctx fn_ret;
            } )
      | _, [] ->
          let ctx =
            List.fold_left2
              (fun ctx param (arg : Typed_ast.expr) ->
                unify_into ctx param arg.ty)
              ctx matched_fn matched_arg
          in
          let remaining_fn = List.map (apply_ty ctx) rest_fn in
          let substituted_ret = apply_ty ctx fn_ret in
          let partial_ty = mk_ty (Ty_Arrow (remaining_fn, substituted_ret)) in
          ( ctx,
            {
              id = e.id;
              loc = loc_of_parsing e.loc;
              expr_desc =
                TExp_Apply
                  { closure_fun = fn; args = List.map (apply_expr_ty ctx) args };
              ty = apply_ty ctx partial_ty;
            } )
      | _, _ ->
          raise
            (Type_error
               (Printf.sprintf "function expects %d argument(s), got %d"
                  (List.length fn_params) (List.length args))))
  | Parsing_ast.Exp_Let ldef ->
      let ctx, tdef = infer_letdef ctx ldef in
      (ctx, { id = e.id; expr_desc = TExp_Let tdef; loc; ty = tdef.value.ty })
  | Parsing_ast.Exp_Assign { target; value } ->
      let ctx, target = infer_expr ctx target in
      let ctx, value = infer_expr ctx value in
      let ctx = unify_into ctx target.ty value.ty in
      let ty = mk_ty (Ty_Constant Ty_Unit) in
      (ctx, { id = e.id; expr_desc = TExp_Assign { target; value }; loc; ty })
  | Parsing_ast.Exp_AssignRef { target; value } ->
      let ctx, target = infer_expr ctx target in
      let ctx, value = infer_expr ctx value in
      let ref_ty = mk_ty (Ty_Ref value.ty) in
      let ctx = unify_into ctx target.ty ref_ty in
      let ty = mk_ty (Ty_Constant Ty_Unit) in
      (ctx, { id = e.id; expr_desc = TExp_AssignRef { target; value }; loc; ty })
  | Parsing_ast.Exp_If { cond; then_branch; else_branch } ->
      let ctx, cond = infer_expr ctx cond in
      let ctx = unify_into ctx cond.ty (mk_ty (Ty_Constant Ty_Bool)) in
      let ctx, then_branch = infer_expr ctx then_branch in
      let ctx, else_branch, out_ty =
        match else_branch with
        | None ->
            let ty = mk_ty (Ty_Constant Ty_Unit) in
            let ctx = unify_into ctx then_branch.ty ty in
            (ctx, None, ty)
        | Some e ->
            let ctx, e = infer_expr ctx e in
            let ctx = unify_into ctx then_branch.ty e.ty in
            (ctx, Some e, apply_ty ctx then_branch.ty)
      in
      ( ctx,
        {
          id = e.id;
          expr_desc = TExp_If { cond; then_branch; else_branch };
          loc;
          ty = out_ty;
        } )
  | Parsing_ast.Exp_While { cond; body } ->
      let ctx, cond = infer_expr ctx cond in
      let ctx = unify_into ctx cond.ty (mk_ty (Ty_Constant Ty_Bool)) in
      let ctx, body = infer_expr ctx body in
      let ty = mk_ty (Ty_Constant Ty_Unit) in
      (ctx, { id = e.id; expr_desc = TExp_While { cond; body }; loc; ty })
  | Parsing_ast.Exp_ForIn { iter_var; iterable; body } ->
      let ctx, iter_var = infer_pattern ctx iter_var in
      let ctx, iterable = infer_expr ctx iterable in
      let ctx, body = infer_expr ctx body in
      let ty = mk_ty (Ty_Constant Ty_Unit) in
      ( ctx,
        {
          id = e.id;
          expr_desc = TExp_ForIn { iter_var; iterable; body };
          loc;
          ty;
        } )
  | Parsing_ast.Exp_Loop { expr } ->
      let ctx, body = infer_expr ctx expr in
      let ctx, ty = fresh_ty ctx in
      (ctx, { id = e.id; expr_desc = TExp_Loop { expr = body }; loc; ty })
  | Parsing_ast.Exp_Break { expr_opt } ->
      let ctx, e_opt =
        match expr_opt with
        | None -> (ctx, None)
        | Some e ->
            let ctx, e = infer_expr ctx e in
            (ctx, Some e)
      in
      let ty = mk_ty (Ty_Constant Ty_Unit) in
      (ctx, { id = e.id; expr_desc = TExp_Break { expr_opt = e_opt }; loc; ty })
  | Parsing_ast.Exp_Continue ->
      let ty = mk_ty (Ty_Constant Ty_Unit) in
      (ctx, { id = e.id; expr_desc = TExp_Continue; loc; ty })
  | Parsing_ast.Exp_Return { expr_opt } ->
      let ctx, e_opt =
        match expr_opt with
        | None -> (ctx, None)
        | Some e ->
            let ctx, e = infer_expr ctx e in
            (ctx, Some e)
      in
      let ty = mk_ty (Ty_Constant Ty_Unit) in
      (ctx, { id = e.id; expr_desc = TExp_Return { expr_opt = e_opt }; loc; ty })
  | Parsing_ast.Exp_Seq { exprs } ->
      let ctx, exprs = List.fold_left_map infer_expr ctx exprs in
      let ty =
        match List.rev exprs with
        | [] -> mk_ty (Ty_Constant Ty_Unit)
        | last :: _ -> last.ty
      in
      (ctx, { id = e.id; expr_desc = TExp_Seq { exprs }; loc; ty })
  | Parsing_ast.Exp_Match { expr = target; cases } ->
      let ctx, target = infer_expr ctx target in
      let ctx, out_ty = fresh_ty ctx in
      let ctx, cases =
        List.fold_left_map
          (fun ctx (c : Parsing_ast.pattern_case) ->
            let ctx, pat = infer_pattern ctx c.pattern in
            let ctx = unify_into ctx target.ty pat.ty in
            let ctx, when_condition =
              match c.when_condition with
              | None -> (ctx, None)
              | Some w ->
                  let ctx, tw = infer_expr ctx w in
                  let ctx =
                    unify_into ctx tw.ty (mk_ty (Ty_Constant Ty_Bool))
                  in
                  (ctx, Some tw)
            in
            let ctx, body = infer_expr ctx c.body in
            let ctx = unify_into ctx body.ty out_ty in
            let tc =
              {
                id = c.id;
                pattern = pat;
                when_condition;
                body;
                loc = loc_of_parsing c.loc;
                ty = body.ty;
              }
            in
            (ctx, tc))
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
      let ctx, idx, field_ty =
        match find_record_by_field_names ctx [ field_name.name ] with
        | Some ty_record_info -> (
            let ctx =
              unify_into ctx record.ty
                (mk_ty
                   (Ty_Defined { name = ty_record_info.ty_decl.name; args = [] }))
            in
            match
              List.find_mapi
                (fun idx (field : record_field_decl) ->
                  if field.field_name.name = field_name.name then
                    Some (idx, field.field_ty)
                  else None)
                ty_record_info.record_fields
            with
            | Some (idx, field_ty) -> (ctx, idx, field_ty)
            | None ->
                raise
                  (Type_error
                     (Printf.sprintf "field '%s' is not found" field_name.name))
            )
        | None ->
            raise
              (Type_error
                 (Printf.sprintf "no record has field_name '%s'" field_name.name))
      in
      ( ctx,
        {
          id = e.id;
          expr_desc = TExp_Field { record; field_name = field_name.name; idx };
          loc;
          ty = field_ty;
        } )
  | Parsing_ast.Exp_Index { collection; index } ->
      let ctx, collection = infer_expr ctx collection in
      let ctx, index = infer_expr ctx index in
      let _ctx = unify_into ctx index.ty (mk_ty (Ty_Constant Ty_Int64)) in
      let ctx, ty = fresh_ty ctx in
      (ctx, { id = e.id; expr_desc = TExp_Index { collection; index }; loc; ty })

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
        let ctx = unify_into ctx fn_ty value.ty in
        (ctx, value)
    | _ -> infer_expr ctx ldef.value
  in
  let ctx, pattern = infer_pattern ctx ldef.pattern in
  let ctx = unify_into ctx pattern.ty value.ty in
  let ctx, ty_opt =
    match ldef.ty_opt with
    | None -> (ctx, None)
    | Some t ->
        let ctx, expected = ty_of_parsing ctx t in
        let ctx = unify_into ctx expected value.ty in
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
  | Parsing_ast.Str_Let ldef ->
      let ctx, ldef = infer_letdef ctx ldef in
      (ctx, { id = si.id; structure_item_desc = TStr_Let ldef; loc })
  | Parsing_ast.Str_Fun { rec_flag; name; body; ty_opt } ->
      let rec_flag =
        match rec_flag with
        | Parsing_ast.Recursive -> TRecursive
        | Parsing_ast.NonRecursive -> TNonRecursive
      in
      let ctx, body =
        match rec_flag with
        | TRecursive ->
            let ctx, fn_ty = fresh_ty ctx in
            let ctx =
              {
                ctx with
                env = TyEnv.extend name.name { vars = []; body = fn_ty } ctx.env;
              }
              (* vars is empty because function will be monomorphic inside its own body.
            TODO: polymorphic recursive function *)
            in
            let ctx, body = infer_expr ctx body in
            let ctx = unify_into ctx fn_ty body.ty in
            (ctx, body)
        | TNonRecursive -> infer_expr ctx body
      in
      let ctx, ty_opt =
        match ty_opt with
        | None -> (ctx, None)
        | Some t ->
            let ctx, t = ty_of_parsing ctx t in
            let ctx = unify_into ctx body.ty t in
            (ctx, Some (apply_ty ctx t))
      in
      let ctx =
        let body_ty = apply_ty ctx body.ty in
        {
          ctx with
          env =
            TyEnv.extend name.name
              {
                vars = ty_vars body_ty |> List.sort_uniq Int.compare;
                body = body_ty;
              }
              ctx.env;
        }
      in
      ( ctx,
        {
          id = si.id;
          structure_item_desc =
            TStr_Fun { rec_flag; name = ident_of_parsing name; body; ty_opt };
          loc;
        } )
  | Parsing_ast.Str_TypeDef td ->
      let ctx, td = ty_decl_of_parsing ctx td in
      let ctx = register_ty_decl ctx td in
      (ctx, { id = si.id; structure_item_desc = TStr_TypeDef td; loc })
  | Parsing_ast.Str_ModuleStruct ms ->
      let ctx, ms = infer_module_structure ctx ms in
      (ctx, { id = si.id; structure_item_desc = TStr_ModuleStruct ms; loc })
  | Parsing_ast.Str_Signature sigs ->
      let ctx, sigs =
        List.fold_left_map
          (fun ctx si ->
            let ctx, si = signature_item_of_parsing ctx si in
            let ctx =
              match si.signature_item_desc with
              | TSig_Fun { name; params; ret_ty; _ } ->
                  let sig_ty =
                    if params = [] then ret_ty
                    else mk_ty (Ty_Arrow (params, ret_ty))
                  in
                  {
                    ctx with
                    env =
                      TyEnv.extend name.name
                        { vars = []; body = sig_ty }
                        ctx.env;
                  }
              | _ -> ctx
            in
            (ctx, si))
          ctx sigs
      in
      (ctx, { id = si.id; structure_item_desc = TStr_Signature sigs; loc })

and infer_module_structure (ctx : infer_ctx) (ms : Parsing_ast.module_structure)
    : infer_ctx * module_structure =
  let loc = loc_of_parsing ms.loc in
  let ctx, structure_items =
    List.fold_left_map infer_structure_item ctx ms.structure_items
  in
  (ctx, { id = ms.id; name = ident_of_parsing ms.name; structure_items; loc })

let validate_main (ms : module_structure) : unit =
  let check_main (si : structure_item) =
    match si.structure_item_desc with
    | TStr_Fun { name = { name = "main"; _ }; body; _ } -> (
        let err msg = raise (Type_error msg) in
        match body.ty.ty_desc with
        | Ty_Arrow ([ arg_ty ], ret_ty) -> (
            if arg_ty.ty_desc <> Ty_Constant Ty_Unit then
              err "main must take unit as its parameter";
            match ret_ty.ty_desc with
            | Ty_Constant (Ty_Unit | Ty_Int64) -> ()
            | _ -> err "main must return unit or int64")
        | _ -> err "main must have type (unit) -> unit or (unit) -> int64")
    | _ -> ()
  in
  List.iter check_main ms.structure_items

let infer_program (program : Parsing_ast.module_structure) :
    infer_ctx * module_structure =
  let ctx, ms = infer_module_structure empty_ctx program in
  let resolve _ ty =
    (* Post-typing pass: walk the entire AST and apply the final substitution,
     replacing all remaining [Ty_Var] unification variables that is
     resolved but not applied to the AST before *)
    Subst.apply ctx.subst ty
  in
  let t = Ast_transformer.{ identity_transformer with ty = resolve } in
  let ms = t.module_structure t ms in
  validate_main ms;
  (ctx, ms)
