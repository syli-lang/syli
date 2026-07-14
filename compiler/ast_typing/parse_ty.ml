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
  | Ty_Float -> TTy_Float
  | Ty_Double -> TTy_Double
  | Ty_StringLit -> TTy_StringLit
  | Ty_CharLit -> TTy_CharLit

let loc_of_parsing (loc : Syli_parsing.Ast.location) : location =
  { start_pos = loc.start_pos; end_pos = loc.end_pos; filename = loc.filename }

let ident_of_parsing (id : Syli_parsing.Ast.ident) : ident =
  { name = id.name; id = id.id; fullname = []; loc = loc_of_parsing id.loc }

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
  | Ty_Arrow (args, ret) ->
      let ctx, args = List.fold_left_map ty_of_parsing ctx args in
      let ctx, ret = ty_of_parsing ctx ret in
      (ctx, mk_ty @@ TTy_Arrow (args, ret))
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
  | Const_FloatLit s -> (TConst_FloatLit s, TTy_Double)
  | Const_CharLit s -> (TConst_CharLit s, TTy_CharLit)
  | Const_StringLit s -> (TConst_StringLit s, TTy_StringLit)

let unop_of_parsing (op : Syli_parsing.Ast.unop) : unop =
  match op with
  | Unop_Logical Not -> TUnop_Logical TNot
  | Unop_Arithmetic Neg -> TUnop_Arithmetic TNeg
  | Unop_Bitwise BitNot -> TUnop_Bitwise TBitNot

let binop_of_parsing (op : Syli_parsing.Ast.binop) : binop =
  match op with
  | Binop_Arithmetic a ->
      TBinop_Arithmetic
        (match a with
        | Add -> TAdd
        | Sub -> TSub
        | Mul -> TMul
        | Div -> TDiv
        | Mod -> TMod)
  | Binop_Logical l -> TBinop_Logical (match l with And -> TAnd | Or -> TOr)
  | Binop_Bitwise b ->
      TBinop_Bitwise
        (match b with
        | BitAnd -> TBitAnd
        | BitOr -> TBitOr
        | BitXor -> TBitXor
        | LShift -> TLShift
        | RShift -> TRShift)
  | Binop_Comparison c ->
      TBinop_Comparison
        (match c with
        | Eq -> TEq
        | Ne -> TNe
        | Lt -> TLt
        | Le -> TLe
        | Gt -> TGt
        | Ge -> TGe)

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
        let ctx, fields =
          List.fold_left_map
            (fun ctx (f : Syli_parsing.Ast.record_field_decl) ->
              let ctx, field_ty = ty_of_parsing ctx f.field_ty in
              ( ctx,
                {
                  id = f.id;
                  field_name = ident_of_parsing f.field_name;
                  field_ty;
                  field_mut = field_mut_of_parsing f.field_mut;
                  loc = loc_of_parsing f.loc;
                } ))
            ctx fields
        in
        (ctx, TTydef_Record fields)
    | Tydef_Variant ctors ->
        let ctx, ctors =
          List.fold_left_map
            (fun ctx (c : Syli_parsing.Ast.variant_constructor_decl) ->
              let ctx, arg =
                match c.arg with
                | None -> (ctx, None)
                | Some t ->
                    let ctx, t = ty_of_parsing ctx t in
                    (ctx, Some t)
              in
              ( ctx,
                {
                  id = c.id;
                  name = ident_of_parsing c.name;
                  arg;
                  loc = loc_of_parsing c.loc;
                } ))
            ctx ctors
        in
        (ctx, TTydef_Variant ctors)
    | Tydef_Abstract -> (ctx, TTydef_Abstract)
  in
  ( ctx,
    {
      id = td.id;
      name = ident_of_parsing td.name;
      params =
        List.map
          (fun p ->
            { name = p; id = Hashtbl.hash (td.id, p); fullname = []; loc })
          td.params;
      def;
      annotations =
        List.map (fun (a : Syli_parsing.Ast.ident) -> a.name) td.annotations;
      loc;
    } )

let external_fn_of_parsing (loc : location) (e : Syli_parsing.Ast.external_fn) :
    external_fn =
  { c_name = e.c_name; calling_convention = e.calling_convention; loc }

let rec signature_item_of_parsing (ctx : Env.infer_ctx)
    (si : Syli_parsing.Ast.signature_item) : Env.infer_ctx * signature_item =
  let loc = loc_of_parsing si.loc in
  match si.signature_item_desc with
  | Sig_Value { name; params; value_ty; external_fn } ->
      let ctx, params = List.fold_left_map ty_of_parsing ctx params in
      let ctx, ret_ty = ty_of_parsing ctx value_ty in
      ( ctx,
        {
          id = si.id;
          signature_item_desc =
            TSig_Fun
              {
                name = ident_of_parsing name;
                params;
                ret_ty;
                external_fn =
                  Option.map (external_fn_of_parsing loc) external_fn;
              };
          loc;
        } )
  | Sig_Type td ->
      let ctx, td = ty_decl_of_parsing ctx td in
      (ctx, { id = si.id; signature_item_desc = TSig_Type td; loc })
  | Sig_Module ms ->
      let ctx, ms = module_signature_of_parsing ctx ms in
      (ctx, { id = si.id; signature_item_desc = TSig_Module ms; loc })

and module_signature_of_parsing (ctx : Env.infer_ctx)
    (ms : Syli_parsing.Ast.module_signature) : Env.infer_ctx * module_signature
    =
  let loc = loc_of_parsing ms.loc in
  let ctx, signature_items =
    List.fold_left_map signature_item_of_parsing ctx ms.signature_items
  in
  (ctx, { id = ms.id; name = ident_of_parsing ms.name; signature_items; loc })
