open Syli_parsing.Ast
open Typed_ast
open Env
open Infer_helpers

let const_ty_of_parsing (c : Syli_parsing.Ast.constant_ty) : constant_ty =
  match c with
  | Ty_Int8 -> TTy_Int8
  | Ty_Int16 -> TTy_Int16
  | Ty_Int32 -> TTy_Int32
  | Ty_Int64 -> TTy_Int64
  | Ty_UInt8 -> TTy_UInt8
  | Ty_UInt16 -> TTy_UInt16
  | Ty_UInt32 -> TTy_UInt32
  | Ty_UInt64 -> TTy_UInt64
  | Ty_Bool -> TTy_Bool
  | Ty_Unit -> TTy_Unit
  | Ty_F32 -> TTy_F32
  | Ty_F64 -> TTy_F64
  | Ty_String -> TTy_String
  | Ty_Char -> TTy_Char

let loc_of_parsing (loc : Syli_parsing.Ast.location) : location =
  { start_pos = loc.start_pos; end_pos = loc.end_pos; filename = loc.filename }

let ident_of_parsing (id : Syli_parsing.Ast.ident) : ident =
  {
    name = id.name;
    id = id.id;
    path = [];
    loc = loc_of_parsing id.loc;
    is_operator = id.is_operator;
  }

let mk_ty ty_desc = { ty_desc }

let rec ty_of_parsing (ctx : Env.infer_ctx) (t : Syli_parsing.Ast.ty) :
    Env.infer_ctx * ty =
  match t.ty_desc with
  | Ty_Any -> (ctx, mk_ty TTy_Any)
  | Ty_Constant c -> (ctx, mk_ty @@ TTy_Constant (const_ty_of_parsing c))
  | Ty_Var _ -> Infer_helpers.fresh_ty ctx
  | Ty_Tuple elems ->
      let ctx, elems = List.fold_left_map ty_of_parsing ctx elems in
      (ctx, mk_ty @@ TTy_Tuple elems)
  | Ty_Arrow (arg, ret) ->
      let ctx, arg = ty_of_parsing ctx arg in
      let ctx, ret = ty_of_parsing ctx ret in
      (ctx, mk_ty @@ TTy_Arrow (arg, ret))
  | Ty_Array elem ->
      let ctx, elem = ty_of_parsing ctx elem in
      (ctx, mk_ty @@ TTy_Array elem)
  | Ty_Defined d ->
      let ctx, args = List.fold_left_map ty_of_parsing ctx d.args in
      (ctx, { ty_desc = TTy_Defined { name = ident_of_parsing d.name; args } })

let constant_desc_of_parsing (d : Syli_parsing.Ast.constant_desc) :
    constant_desc * constant_ty =
  match d with
  | Const_Unit -> (TConst_Unit, TTy_Unit)
  | Const_BoolLit s -> (TConst_BoolLit s, TTy_Bool)
  | Const_IntLit s -> (TConst_IntLit s, TTy_Int64)
  | Const_FloatLit s -> (TConst_FloatLit s, TTy_F64)
  | Const_CharLit s -> (TConst_CharLit s, TTy_Char)
  | Const_StringLit s -> (TConst_StringLit s, TTy_String)

let field_mut_of_parsing = function
  | Mutable -> TMutable
  | Immutable -> TImmutable

let rec ty_decl_of_parsing (ctx : Env.infer_ctx) (td : Syli_parsing.Ast.ty_decl)
    : Env.infer_ctx * ty_decl =
  let loc = loc_of_parsing td.loc in
  let ctx, def =
    match td.def with
    | Tydef_Alias t ->
        let ctx, t = ty_of_parsing ctx t in
        (ctx, TTydef_Alias t)
    | Tydef_Record fields ->
        let (ctx, _), fields =
          List.fold_left_map
            (fun (ctx, i) (f : Syli_parsing.Ast.record_field_decl) ->
              let ctx, field_ty = ty_of_parsing ctx f.field_ty in
              ( (ctx, i + 1),
                ({
                   id = f.id;
                   field_name = ident_of_parsing f.field_name;
                   field_idx = i;
                   field_ty;
                   field_mut = field_mut_of_parsing f.field_mut;
                   loc = loc_of_parsing f.loc;
                 }
                  : Typed_ast.record_field_decl) ))
            (ctx, 0) fields
        in
        (ctx, TTydef_Record fields)
    | Tydef_Variant ctors ->
        let (ctx, _), ctors =
          List.fold_left_map
            (fun (ctx, i) (c : Syli_parsing.Ast.variant_constructor_decl) ->
              let ctx, arg =
                match c.arg with
                | None -> (ctx, None)
                | Some (Syli_parsing.Ast.Constr_ty t) ->
                    let ctx, t = ty_of_parsing ctx t in
                    (ctx, Some (Constr_ty t))
                | Some (Syli_parsing.Ast.Constr_record fields) ->
                    let (ctx, _), fields =
                      List.fold_left_map
                        (fun (ctx, i) (f : Syli_parsing.Ast.record_field_decl)
                           ->
                          let ctx, field_ty = ty_of_parsing ctx f.field_ty in
                          ( (ctx, i + 1),
                            ({
                               id = f.id;
                               field_name = ident_of_parsing f.field_name;
                               field_idx = i;
                               field_ty;
                               field_mut = field_mut_of_parsing f.field_mut;
                               loc = loc_of_parsing f.loc;
                             }
                              : Typed_ast.record_field_decl) ))
                        (ctx, 0) fields
                    in
                    (ctx, Some (Constr_record fields))
              in
              ( (ctx, i + 1),
                {
                  id = c.id;
                  name = ident_of_parsing c.name;
                  arg;
                  tag = i;
                  loc = loc_of_parsing c.loc;
                } ))
            (ctx, 0) ctors
        in
        (ctx, TTydef_Variant ctors)
    | Tydef_Abstract -> (ctx, TTydef_Abstract)
  in
  ( ctx,
    {
      id = td.id;
      name = ident_of_parsing td.name;
      params = List.map ident_of_parsing td.params;
      def;
      annotations =
        List.map (fun (a : Syli_parsing.Ast.ident) -> a.name) td.annotations;
      loc;
    } )

let symbol_of_parsing (s : Syli_parsing.Ast.symbol) : symbol =
  { name = s.name; loc = loc_of_parsing s.loc }

let external_fn_of_parsing (e : Syli_parsing.Ast.external_fn) : external_fn =
  {
    symbol = symbol_of_parsing e.symbol;
    kind = (match e.kind with Foreign -> Foreign | Primitive -> Primitive);
    calling_convention = e.calling_convention;
  }

let rec signature_item_of_parsing (ctx : Env.infer_ctx)
    (si : Syli_parsing.Ast.signature_item) : Env.infer_ctx * signature_item =
  let loc = loc_of_parsing si.loc in
  match si.signature_item_desc with
  | Sig_Value { name; ty } ->
      let ctx, ty = ty_of_parsing ctx ty in
      ( ctx,
        {
          id = si.id;
          signature_item_desc = TSig_Value { name = ident_of_parsing name; ty };
          loc;
        } )
  | Sig_External { fname; ty; external_fn } ->
      let ctx, ty = ty_of_parsing ctx ty in
      ( ctx,
        {
          id = si.id;
          signature_item_desc =
            TSig_External
              {
                fname = ident_of_parsing fname;
                ty;
                external_fn = external_fn_of_parsing external_fn;
              };
          loc;
        } )
  | Sig_Type td ->
      let ctx, td = ty_decl_of_parsing ctx td in
      (ctx, { id = si.id; signature_item_desc = TSig_Type td; loc })
  | Sig_ModuleSignature ms ->
      let ctx, ms = module_signature_of_parsing ctx ms in
      (ctx, { id = si.id; signature_item_desc = TSig_ModuleSignature ms; loc })

and module_signature_of_parsing (ctx : Env.infer_ctx)
    (ms : Syli_parsing.Ast.module_signature) : Env.infer_ctx * module_signature
    =
  let loc = loc_of_parsing ms.loc in
  let ctx, signature_items =
    List.fold_left_map signature_item_of_parsing ctx ms.signature_items
  in
  (ctx, { id = ms.id; name = ident_of_parsing ms.name; signature_items; loc })
