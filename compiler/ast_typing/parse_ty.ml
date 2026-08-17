open Syli_parsing.Ast
open Syli_parsing.Types
open Typed_ast
open Env
open Infer_helpers

let loc_of_parsing (loc : Syli_parsing.Types.location) : location = loc
let ident_of_parsing (id : Syli_parsing.Types.ident) : ident = id

let rec ty_of_parsing (ctx : Env.infer_ctx) (t : Syli_parsing.Types.ty) :
    Env.infer_ctx * ty =
  match t.ty_desc with
  | Ty_Any | Ty_Constant _ -> (ctx, t)
  | Ty_Var { label; variable = Some _ } -> (ctx, t)
  | Ty_Var { label; variable = None } ->
      let v = Syli_parsing.Ast.fresh_id () in
      (ctx, { t with ty_desc = Ty_Var { label; variable = Some v } })
  | Ty_Tuple elems ->
      let ctx, elems = List.fold_left_map ty_of_parsing ctx elems in
      (ctx, { t with ty_desc = Ty_Tuple elems })
  | Ty_Arrow (args, ret) ->
      let ctx, args = List.fold_left_map ty_of_parsing ctx args in
      let ctx, ret = ty_of_parsing ctx ret in
      (ctx, { t with ty_desc = Ty_Arrow (args, ret) })
  | Ty_Array elem ->
      let ctx, elem = ty_of_parsing ctx elem in
      (ctx, { t with ty_desc = Ty_Array elem })
  | Ty_Ref elem ->
      let ctx, elem = ty_of_parsing ctx elem in
      (ctx, { t with ty_desc = Ty_Ref elem })
  | Ty_Defined { name; args } ->
      let ctx, args = List.fold_left_map ty_of_parsing ctx args in
      (ctx, { t with ty_desc = Ty_Defined { name; args } })

let constant_desc_of_parsing (d : Syli_parsing.Ast.constant_desc) :
    constant_desc * constant_ty =
  match d with
  | Const_Unit -> (TConst_Unit, Ty_Unit)
  | Const_BoolLit s -> (TConst_BoolLit s, Ty_Bool)
  | Const_IntLit s -> (TConst_IntLit s, Ty_Int64)
  | Const_FloatLit s -> (TConst_FloatLit s, Ty_Double)
  | Const_CharLit s -> (TConst_CharLit s, Ty_CharLit)
  | Const_StringLit s -> (TConst_StringLit s, Ty_StringLit)

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

let rec ty_decl_of_parsing (ctx : Env.infer_ctx)
    (td : Syli_parsing.Types.ty_decl) : Env.infer_ctx * ty_decl =
  let ctx, def =
    match td.def with
    | Tydef_Alias t ->
        let ctx, t = ty_of_parsing ctx t in
        (ctx, Tydef_Alias t)
    | Tydef_Record fields ->
        let ctx, fields =
          List.fold_left_map
            (fun ctx (f : Syli_parsing.Types.record_field_decl) ->
              let ctx, field_ty = ty_of_parsing ctx f.field_ty in
              (ctx, { f with field_ty }))
            ctx fields
        in
        (ctx, Tydef_Record fields)
    | Tydef_Variant ctors ->
        let ctx, ctors =
          List.fold_left_map
            (fun ctx (c : Syli_parsing.Types.variant_constructor_decl) ->
              let ctx, arg =
                match c.arg with
                | None -> (ctx, None)
                | Some (Constr_ty t) ->
                    let ctx, t = ty_of_parsing ctx t in
                    (ctx, Some (Constr_ty t))
                | Some (Constr_record fields) ->
                    let ctx, fields =
                      List.fold_left_map
                        (fun ctx (f : Syli_parsing.Types.record_field_decl) ->
                          let ctx, field_ty = ty_of_parsing ctx f.field_ty in
                          (ctx, { f with field_ty }))
                        ctx fields
                    in
                    (ctx, Some (Constr_record fields))
              in
              (ctx, { c with arg }))
            ctx ctors
        in
        (ctx, Tydef_Variant ctors)
    | Tydef_Abstract -> (ctx, Tydef_Abstract)
  in
  (ctx, { td with def })

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
