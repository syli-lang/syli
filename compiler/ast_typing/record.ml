open Typed_ast
open Env

let record_key_of_expr_fields (fields : record_field list) : string =
  record_key_of_field_names
    (List.map (fun (f : record_field) -> f.field_name.name) fields)

let find_record_field_decl_by_name (fields : record_field_decl list)
    (name : string) : record_field_decl option =
  List.find_opt (fun (f : record_field_decl) -> f.field_name.name = name) fields

let compatible_record_field_ty (decl_ty : ty) (expr_ty : ty) : bool =
  Ty.equal_ty decl_ty expr_ty

let filter_record_candidates (candidates : ty_record_info list)
    (record_fields : record_field list) : ty_record_info list =
  List.filter
    (fun record ->
      match record.ty_decl.def with
      | TTydef_Record decl_fields ->
          List.for_all
            (fun (field : record_field) ->
              match
                find_record_field_decl_by_name decl_fields field.field_name.name
              with
              | None -> false
              | Some decl_record_field ->
                  compatible_record_field_ty decl_record_field.field_ty
                    field.field_value.ty)
            record_fields
      | TTydef_Alias _ | TTydef_Variant _ | TTydef_Abstract -> false)
    candidates

let filter_record_candidates_by_field_type (candidates : ty_record_info list)
    (field_ty : ty) : ty_record_info list =
  List.filter
    (fun record ->
      match record.ty_decl.def with
      | TTydef_Record fields ->
          List.exists
            (fun (info : record_field_decl) ->
              Ty.equal_ty info.field_ty field_ty)
            fields
      | TTydef_Alias _ | TTydef_Variant _ | TTydef_Abstract -> false)
    candidates

let filter_record_candidates_by_expr_fields (candidates : ty_record_info list)
    (fields : record_field list)
    ~(compatible : record_field_decl -> record_field -> bool) :
    ty_record_info list =
  List.filter
    (fun record ->
      match record.ty_decl.def with
      | TTydef_Record decl_fields ->
          List.for_all
            (fun (f : record_field) ->
              match
                find_record_field_decl_by_name decl_fields f.field_name.name
              with
              | None -> false
              | Some decl_field -> compatible decl_field f)
            fields
      | TTydef_Alias _ | TTydef_Variant _ | TTydef_Abstract -> false)
    candidates

let filter_record_candidates_by_types (ctx : infer_ctx)
    (candidates : ty_record_info list) (field_tys : ty list) :
    ty_record_info list =
  List.fold_left
    (fun candidates field_ty ->
      filter_record_candidates_by_field_type candidates field_ty)
    candidates field_tys

let field_index_of_record_ty ctx (record_ty : ty) (field_name : string) :
    (int * ty) option =
  match record_ty.ty_desc with
  | TTy_Defined { name; _ } -> (
      match lookup_ty_decl_by_name ctx name.name with
      | Some td -> (
          match td.def with
          | TTydef_Record fields ->
              List.find_mapi
                (fun idx (f : record_field_decl) ->
                  if f.field_name.name = field_name then Some (idx, f.field_ty)
                  else None)
                fields
          | _ -> None)
      | None -> None)
  | _ -> None
