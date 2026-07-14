open Syli_typing.Typed_ast
open Syli_core.Core_ast
module Typed_ast = Syli_typing.Typed_ast
open Syli_common

exception Desugar_error of string

type env = {
  current_path : string list;
  subst : string StringMap.t;
  fn_scope : string list;
}

let loc_of_typed (loc : Typed_ast.location) : location =
  {
    filename = loc.filename;
    span = { start_pos = loc.start_pos; end_pos = loc.end_pos };
  }

let string_of_loc (loc : Typed_ast.location) : string =
  Printf.sprintf "%s:%d-%d" loc.filename loc.start_pos loc.end_pos

let error_at (loc : Typed_ast.location) (msg : string) : 'a =
  raise (Desugar_error (Printf.sprintf "%s: %s" (string_of_loc loc) msg))

let qualify_name (env : env) (name : string) : string =
  match StringMap.find_opt name env.subst with
  | Some qname -> qname
  | None -> name

let toplevel_name (env : env) (name : string) : string =
  match env.current_path with
  | [] -> name
  | path -> String.concat "." (path @ [ name ])

let rec desugar_ty (t : Typed_ast.ty) : ty =
  let ty_desc =
    match t.ty_desc with
    | TTy_Var v -> CTy_Var v
    | TTy_Any -> CTy_Var (-1)
    | TTy_Constant c ->
        CTy_Constant
          (match c with
          | TTy_Int8 -> CTy_Int8
          | TTy_Int16 -> CTy_Int16
          | TTy_Int32 -> CTy_Int32
          | TTy_Int64 -> CTy_Int64
          | TTy_UInt8 -> CTy_UInt8
          | TTy_UInt16 -> CTy_UInt16
          | TTy_UInt32 -> CTy_UInt32
          | TTy_UInt64 -> CTy_UInt64
          | TTy_Bool -> CTy_Bool
          | TTy_Unit -> CTy_Unit
          | TTy_Float -> CTy_Float
          | TTy_Double -> CTy_Double
          | TTy_StringLit -> CTy_StringLit
          | TTy_CharLit -> CTy_CharLit)
    | TTy_Arrow (args, ret) ->
        CTy_Arrow (List.map desugar_ty args, desugar_ty ret)
    | TTy_Tuple elems -> CTy_Tuple (List.map desugar_ty elems)
    | TTy_Array elem -> CTy_Array (desugar_ty elem)
    | TTy_Defined d ->
        CTy_Defined
          {
            name =
              {
                fullname = d.name.name;
                id = d.name.id;
                loc = loc_of_typed d.name.loc;
              };
            args = List.map desugar_ty d.args;
          }
  in
  { ty_desc }

let desugar_unop (u : Typed_ast.unop) : unop =
  match u with
  | TUnop_Logical TNot -> (CUnop_Logical CNot : unop)
  | TUnop_Arithmetic TNeg -> (CUnop_Arithmetic CNeg : unop)
  | TUnop_Bitwise TBitNot -> (CUnop_Bitwise CBitNot : unop)

let desugar_binop (b : Typed_ast.binop) : binop =
  match b with
  | TBinop_Arithmetic a ->
      CBinop_Arithmetic
        (match a with
        | TAdd -> CAdd
        | TSub -> CSub
        | TMul -> CMul
        | TDiv -> CDiv
        | TMod -> CMod)
  | TBinop_Logical l ->
      CBinop_Logical (match l with TAnd -> CAnd | TOr -> COr)
  | TBinop_Bitwise b ->
      CBinop_Bitwise
        (match b with
        | TBitAnd -> CBitAnd
        | TBitOr -> CBitOr
        | TBitXor -> CBitXor
        | TLShift -> CLShift
        | TRShift -> CRShift)
  | TBinop_Comparison c ->
      CBinop_Comparison
        (match c with
        | TEq -> CEq
        | TNe -> CNe
        | TLt -> CLt
        | TLe -> CLe
        | TGt -> CGt
        | TGe -> CGe)

let const_expr_for_pattern (p : Typed_ast.pattern) (loc : location) :
    expr option =
  let mk node ty = { id = p.id; node; loc; ty = desugar_ty ty } in
  match p.pattern_desc with
  | TPat_Unit -> Some (mk (CExp_Constant CConst_Unit) p.ty)
  | TPat_BoolLit s -> Some (mk (CExp_Constant (CConst_BoolLit s)) p.ty)
  | TPat_IntLit s -> Some (mk (CExp_Constant (CConst_IntLit s)) p.ty)
  | TPat_FloatLit s -> Some (mk (CExp_Constant (CConst_FloatLit s)) p.ty)
  | TPat_CharLit s -> Some (mk (CExp_Constant (CConst_CharLit s)) p.ty)
  | TPat_StringLit s -> Some (mk (CExp_Constant (CConst_StringLit s)) p.ty)
  | TPat_Wildcard -> None
  | _ -> None

let hash_index (name : string) : int = abs (Hashtbl.hash name)

let desugar_lambda_params (env : env) (params : Typed_ast.param list) :
    ident list * env =
  let idents, names =
    List.split
      (List.filter_map
         (fun (p : Typed_ast.param) ->
           match p.pattern.pattern_desc with
           | TPat_Ident name ->
               Some
                 ( {
                     fullname = name.name;
                     id = p.pattern.id;
                     loc = loc_of_typed p.pattern.loc;
                   },
                   name.name )
           | TPat_Unit -> None
           | _ -> error_at p.loc "lambda parameter must desugar to identifier")
         params)
  in
  let env' =
    {
      env with
      subst = List.fold_left (fun s n -> StringMap.remove n s) env.subst names;
    }
  in
  (idents, env')

let rec desugar_expr (env : env) (e : Typed_ast.expr) : expr * env =
  let loc = loc_of_typed e.loc in
  let ty = desugar_ty e.ty in
  let node, env' =
    match e.expr_desc with
    | TExp_Constant c ->
        ( CExp_Constant
            (match c.constant_desc with
            | TConst_Unit -> CConst_Unit
            | TConst_BoolLit s -> CConst_BoolLit s
            | TConst_IntLit s -> CConst_IntLit s
            | TConst_FloatLit s -> CConst_FloatLit s
            | TConst_CharLit s -> CConst_CharLit s
            | TConst_StringLit s -> CConst_StringLit s),
          env )
    | TExp_Ident i ->
        ( CExp_Ident
            {
              fullname = qualify_name env i.name;
              id = i.id;
              loc = loc_of_typed i.loc;
            },
          env )
    | TExp_Tuple _ ->
        error_at e.loc "tuple expressions are not lowered to Core yet"
    | TExp_Record fields ->
        let lowered_fields =
          fields
          |> List.mapi (fun i (f : Typed_ast.record_field) ->
              {
                field_idx = i;
                field_ty = desugar_ty f.field_value.ty;
                field_value = fst (desugar_expr env f.field_value);
              })
        in
        (CExp_Record lowered_fields, env)
    | TExp_Collection _ ->
        error_at e.loc "collection literals are not lowered to Core yet"
    | TExp_VariantConstructor { name; args } ->
        let tag = hash_index name.name in
        ( CExp_VariantConstructor
            { tag; arg = Option.map (fun a -> fst (desugar_expr env a)) args },
          env )
    | TExp_ArrayCreate { lambda_init; element_ty; size } ->
        let lambda_init = (lambda_init : Typed_ast.lambda) in
        let params, env_params = desugar_lambda_params env lambda_init.params in
        let ret_ty =
          match lambda_init.ret_ty with
          | Some rt -> desugar_ty rt
          | None -> desugar_ty lambda_init.body.ty
        in
        let init_fun =
          {
            params;
            body = fst (desugar_expr env_params lambda_init.body);
            ret_ty;
          }
        in
        ( CExp_ArrayCreate
            {
              init_fun;
              element_ty = desugar_ty element_ty;
              size = fst (desugar_expr env size);
            },
          env )
    | TExp_ArrayLength arr ->
        (CExp_ArrayLength (fst (desugar_expr env arr)), env)
    | TExp_ArrayGet { arr; idx } ->
        ( CExp_ArrayGet
            {
              arr = fst (desugar_expr env arr);
              idx = fst (desugar_expr env idx);
            },
          env )
    | TExp_ArraySet { arr; idx; value } ->
        ( CExp_ArraySet
            {
              arr = fst (desugar_expr env arr);
              idx = fst (desugar_expr env idx);
              value = fst (desugar_expr env value);
            },
          env )
    | TExp_UnOp (op, x) ->
        (CExp_UnOp (desugar_unop op, fst (desugar_expr env x)), env)
    | TExp_BinOp (op, x, y) ->
        ( CExp_BinOp
            ( desugar_binop op,
              fst (desugar_expr env x),
              fst (desugar_expr env y) ),
          env )
    | TExp_Lambda l ->
        let l = (l : Typed_ast.lambda) in
        let params, env_params = desugar_lambda_params env l.params in
        let ret_ty =
          match l.ret_ty with
          | Some rt -> desugar_ty rt
          | None -> desugar_ty l.body.ty
        in
        ( CExp_Lambda
            { params; body = fst (desugar_expr env_params l.body); ret_ty },
          env )
    | TExp_Apply { closure_fun; args } ->
        let args =
          List.filter_map
            (fun a ->
              match a.expr_desc with
              | TExp_Constant { constant_desc = TConst_Unit; _ } -> None
              | _ -> Some (fst (desugar_expr env a)))
            args
        in
        ( CExp_Apply { closure_fun = fst (desugar_expr env closure_fun); args },
          env )
    | TExp_Let l ->
        let name =
          match l.pattern.pattern_desc with
          | TPat_Ident name -> name
          | _ -> error_at l.loc "only identifier is supported for now"
        in
        let qualified_name =
          match env.fn_scope with
          | parent :: _ -> parent ^ "__" ^ name.name
          | [] -> name.name
        in
        let body_env =
          {
            env with
            subst = StringMap.add name.name qualified_name env.subst;
            fn_scope = qualified_name :: env.fn_scope;
          }
        in
        let env' = { body_env with fn_scope = env.fn_scope } in
        ( CExp_Let
            {
              rec_flag =
                (match l.rec_flag with
                | TRecursive -> CRecursive
                | TNonRecursive -> CNonRecursive);
              name =
                {
                  fullname = qualified_name;
                  id = l.pattern.id;
                  loc = loc_of_typed l.loc;
                };
              value = fst (desugar_expr body_env l.value);
            },
          env' )
    | TExp_Assign { target; value } -> (
        let target_e = fst (desugar_expr env target) in
        let value_e = fst (desugar_expr env value) in
        match target_e.node with
        | CExp_Field { record; field_idx } ->
            (CExp_FieldSet { record; field_idx; value = value_e }, env)
        | _ -> error_at target.loc "assignment target is not a field in Core")
    | TExp_If { cond; then_branch; else_branch } ->
        ( CExp_If
            {
              cond = fst (desugar_expr env cond);
              then_branch = fst (desugar_expr env then_branch);
              else_branch =
                Option.map (fun e -> fst (desugar_expr env e)) else_branch;
            },
          env )
    | TExp_While { cond; body } ->
        ( CExp_Loop
            {
              id = e.id;
              node =
                CExp_If
                  {
                    cond = fst (desugar_expr env cond);
                    then_branch =
                      {
                        id = body.id;
                        node =
                          CExp_Seq
                            [
                              fst (desugar_expr env body);
                              {
                                id = body.id;
                                node = CExp_Continue;
                                loc = loc_of_typed body.loc;
                                ty = desugar_ty body.ty;
                              };
                            ];
                        loc = loc_of_typed body.loc;
                        ty = desugar_ty body.ty;
                      };
                    else_branch =
                      Some
                        {
                          id = e.id;
                          node = CExp_Break None;
                          loc = loc_of_typed e.loc;
                          ty = desugar_ty e.ty;
                        };
                  };
              loc = loc_of_typed e.loc;
              ty = desugar_ty e.ty;
            },
          env )
    | TExp_ForIn _ -> error_at e.loc "for-in is not lowered to Core yet"
    | TExp_Loop body -> (CExp_Loop (fst (desugar_expr env body)), env)
    | TExp_Break v ->
        (CExp_Break (Option.map (fun e -> fst (desugar_expr env e)) v), env)
    | TExp_Continue -> (CExp_Continue, env)
    | TExp_Return v ->
        (CExp_Return (Option.map (fun e -> fst (desugar_expr env e)) v), env)
    | TExp_Seq xs ->
        let exprs, final_env =
          List.fold_left
            (fun (acc, e) x ->
              let e', env' = desugar_expr e x in
              (e' :: acc, env'))
            ([], env) xs
        in
        (CExp_Seq (List.rev exprs), final_env)
    | TExp_Match (scrutinee, cases) ->
        let scrutinee' = fst (desugar_expr env scrutinee) in
        let lowered, default_case =
          List.fold_left
            (fun (cases_acc, default_acc) c ->
              match const_expr_for_pattern c.pattern (loc_of_typed c.loc) with
              | Some pconst ->
                  ( (pconst, fst (desugar_expr env c.body)) :: cases_acc,
                    default_acc )
              | None -> (
                  let d = Some (fst (desugar_expr env c.body)) in
                  ( cases_acc,
                    match default_acc with None -> d | Some _ -> default_acc )))
            ([], None) cases
        in
        ( CExp_Switch
            {
              scrutinee = scrutinee';
              cases = List.rev lowered;
              default = default_case;
            },
          env )
    | TExp_Field { record; idx } ->
        ( CExp_Field { record = fst (desugar_expr env record); field_idx = idx },
          env )
    | TExp_Index { collection; index } ->
        ( CExp_ArrayGet
            {
              arr = fst (desugar_expr env collection);
              idx = fst (desugar_expr env index);
            },
          env )
  in
  ({ id = e.id; node; loc; ty }, env')

let desugar_type_decl (env : env) (td : Typed_ast.ty_decl) : ty_decl =
  let def =
    match td.def with
    | TTydef_Alias t -> CTydef_Alias (desugar_ty t)
    | TTydef_Variant ctors ->
        CTydef_Variant
          (ctors
          |> List.mapi (fun i (c : Typed_ast.variant_constructor_decl) ->
              { id = c.id; variant_tag = i; arg = Option.map desugar_ty c.arg })
          )
    | TTydef_Record fields ->
        CTydef_Record
          (fields
          |> List.mapi (fun i (f : Typed_ast.record_field_decl) ->
              {
                id = f.id;
                field_idx = i;
                field_ty = desugar_ty f.field_ty;
                field_mut =
                  (match f.field_mut with
                  | TMutable -> CMutable
                  | TImmutable -> CImmutable);
              }))
    | TTydef_Abstract -> CTydef_Abstract
  in
  {
    id = td.id;
    name =
      { fullname = td.name.name; id = td.name.id; loc = loc_of_typed td.loc };
    params = List.map (fun (p : Typed_ast.ident) -> p.name) td.params;
    def;
  }

let rec desugarize_structure_items (env : env)
    (items : Typed_ast.structure_item list) : structure_item list =
  let _, result =
    List.fold_left
      (fun (env, acc) (item : Typed_ast.structure_item) ->
        match item.structure_item_desc with
        | Typed_ast.TStr_Let l ->
            let name =
              match l.pattern.pattern_desc with
              | TPat_Ident n -> n
              | _ ->
                  error_at l.loc
                    "top-level let pattern must desugar to identifier"
            in
            let qname = toplevel_name env name.name in
            let body_env =
              {
                env with
                subst = StringMap.add name.name qname env.subst;
                fn_scope = qname :: env.fn_scope;
              }
            in
            let env' = { body_env with fn_scope = env.fn_scope } in
            ( env',
              {
                id = item.id;
                structure_item_desc =
                  CStr_Let
                    {
                      rec_flag =
                        (match l.rec_flag with
                        | TRecursive -> CRecursive
                        | TNonRecursive -> CNonRecursive);
                      name =
                        {
                          fullname = qname;
                          id = l.pattern.id;
                          loc = loc_of_typed l.loc;
                        };
                      value = fst (desugar_expr body_env l.value);
                    };
              }
              :: acc )
        | Typed_ast.TStr_Fun { rec_flag; name; body; _ } ->
            let qname = toplevel_name env name.name in
            let body_env =
              {
                env with
                subst = StringMap.add name.name qname env.subst;
                fn_scope = qname :: env.fn_scope;
              }
            in
            let env' = { body_env with fn_scope = env.fn_scope } in
            ( env',
              {
                id = item.id;
                structure_item_desc =
                  CStr_Let
                    {
                      rec_flag =
                        (match rec_flag with
                        | TRecursive -> CRecursive
                        | TNonRecursive -> CNonRecursive);
                      name =
                        {
                          fullname = qname;
                          id = item.id;
                          loc = loc_of_typed item.loc;
                        };
                      value = fst (desugar_expr body_env body);
                    };
              }
              :: acc )
        | Typed_ast.TStr_TypeDef td ->
            ( env,
              {
                id = item.id;
                structure_item_desc = CStr_TypeDef (desugar_type_decl env td);
              }
              :: acc )
        | Typed_ast.TStr_ModuleStruct ms ->
            let env' =
              {
                current_path = env.current_path @ [ ms.name.name ];
                subst = env.subst;
                fn_scope = env.fn_scope;
              }
            in
            let items' = desugarize_structure_items env' ms.structure_items in
            (env, List.rev_append items' acc)
        | Typed_ast.TStr_Signature _ -> (env, acc))
      (env, []) items
  in
  List.rev result

let rec desugarize_signature_items (env : env)
    (items : Typed_ast.signature_item list) : signature_item list =
  List.concat_map
    (fun (item : Typed_ast.signature_item) ->
      match item.signature_item_desc with
      | Typed_ast.TSig_Fun { name; params; ret_ty; external_fn } ->
          let qname = toplevel_name env name.name in
          [
            {
              id = item.id;
              signature_item_desc =
                CSig_Fun
                  {
                    name =
                      {
                        fullname = qname;
                        id = name.id;
                        loc = loc_of_typed name.loc;
                      };
                    params = List.map desugar_ty params;
                    ret_ty = desugar_ty ret_ty;
                    external_fn =
                      Option.map
                        (fun (e : Typed_ast.external_fn) ->
                          ({
                             c_name = e.c_name;
                             calling_convention = e.calling_convention;
                           }
                            : Syli_core.Core_ast.external_fn))
                        external_fn;
                  };
            };
          ]
      | Typed_ast.TSig_Type td ->
          [
            {
              id = item.id;
              signature_item_desc = CSig_Type (desugar_type_decl env td);
            };
          ]
      | Typed_ast.TSig_Module ms ->
          let env =
            {
              current_path = env.current_path @ [ ms.name.name ];
              subst = env.subst;
              fn_scope = env.fn_scope;
            }
          in
          desugarize_signature_items env ms.signature_items)
    items

let desugarize_module_signature (module_signature : Typed_ast.module_signature)
    : signature_item list =
  desugarize_signature_items
    {
      current_path = [ module_signature.name.name ];
      subst = StringMap.empty;
      fn_scope = [];
    }
    module_signature.signature_items

let desugarize_module_structure (module_structure : Typed_ast.module_structure)
    (env : env) : program_core =
  let signature_items =
    List.concat_map
      (fun (item : Typed_ast.structure_item) ->
        match item.structure_item_desc with
        | Typed_ast.TStr_Signature sigs -> desugarize_signature_items env sigs
        | _ -> [])
      module_structure.structure_items
  in
  {
    id = module_structure.id;
    name =
      {
        fullname = module_structure.name.name;
        id = module_structure.name.id;
        loc = loc_of_typed module_structure.name.loc;
      };
    structure_items =
      desugarize_structure_items env module_structure.structure_items;
    signature_items;
    has_main_function = false;
  }

let prefix_syli = "syli"

let desugarize_ast (program : Typed_ast.module_structure) : program_core =
  let root_env =
    {
      current_path = [ prefix_syli ^ program.name.name ];
      subst = StringMap.empty;
      fn_scope = [];
    }
  in
  let signature_items =
    List.concat_map
      (fun (item : Typed_ast.structure_item) ->
        match item.structure_item_desc with
        | Typed_ast.TStr_Signature sigs ->
            desugarize_signature_items root_env sigs
        | _ -> [])
      program.structure_items
  in
  let extern_names =
    (* Needed for substituting extern function names in the code body. *)
    List.concat_map
      (fun (item : Typed_ast.structure_item) ->
        match item.structure_item_desc with
        | Typed_ast.TStr_Signature sigs ->
            List.filter_map
              (fun (si : Typed_ast.signature_item) ->
                match si.signature_item_desc with
                | Typed_ast.TSig_Fun { name; external_fn = Some _; _ } ->
                    Some (name.name, toplevel_name root_env name.name)
                | _ -> None)
              sigs
        | _ -> [])
      program.structure_items
  in
  let root_env =
    {
      root_env with
      subst =
        List.fold_left
          (fun s (n, q) -> StringMap.add n q s)
          root_env.subst extern_names;
    }
  in
  {
    id = 0;
    name =
      {
        fullname = program.name.name;
        id = program.name.id;
        loc = loc_of_typed program.name.loc;
      };
    structure_items =
      desugarize_structure_items root_env program.structure_items;
    signature_items;
    has_main_function = false;
  }

let lower program = desugarize_ast program
