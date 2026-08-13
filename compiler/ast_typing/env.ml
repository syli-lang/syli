open Typed_ast
open Syli_common

exception Type_error of string

type scheme = { vars : int list; body : ty }

let scheme_vars (s : scheme) : int list = s.vars
let scheme_ty (s : scheme) : ty = s.body

module TyEnv = struct
  module M = StringMap

  type t = scheme M.t

  let empty = M.empty
  let extend name scheme env = M.add name scheme env
  let lookup_opt name env = M.find_opt name env
  let bindings env = M.bindings env
end

type ty_record_info = {
  record_fields : record_field_decl list;
  ty_decl : ty_decl;
}

type infer_ctx = {
  env : TyEnv.t;
  subst : Subst.t;
  return_ty : ty option;
  break_ty : ty option;
  record_env : ty_record_info list StringMap.t;
  ty_name_env : ty_decl StringMap.t;
}

let empty_ctx =
  {
    env = TyEnv.empty;
    subst = Subst.empty;
    return_ty = None;
    break_ty = None;
    record_env = StringMap.empty;
    ty_name_env = StringMap.empty;
  }

let register_ty_decl (ctx : infer_ctx) (td : ty_decl) : infer_ctx =
  match td.def with
  | TTydef_Record fields ->
      let record_env =
        List.fold_left
          (fun record_env (field : record_field_decl) ->
            match StringMap.find_opt field.field_name.name record_env with
            | Some ty_record_infos ->
                StringMap.add field.field_name.name
                  ({ record_fields = fields; ty_decl = td } :: ty_record_infos)
                  record_env
            | None ->
                StringMap.add field.field_name.name
                  [ { record_fields = fields; ty_decl = td } ]
                  record_env)
          ctx.record_env fields
      in
      {
        ctx with
        record_env;
        ty_name_env = StringMap.add td.name.name td ctx.ty_name_env;
      }
  | TTydef_Alias _ | TTydef_Variant _ | TTydef_Abstract -> ctx

let find_record_by_field_names ctx field_names : ty_record_info option =
  match field_names with
  | field_name :: _ -> (
      match StringMap.find_opt field_name ctx.record_env with
      | Some ty_record_infos ->
          List.find_opt
            (fun record_info ->
              List.for_all
                (fun field_name ->
                  List.exists
                    (fun (record_field : record_field_decl) ->
                      field_name = record_field.field_name.name)
                    record_info.record_fields)
                field_names)
            ty_record_infos
      | None -> None)
  | [] -> None
