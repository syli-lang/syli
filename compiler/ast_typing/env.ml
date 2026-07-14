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

type ty_record_info = { ty_decl : ty_decl; key : string }
(** the key here is the concatenation of the field names *)

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

let lookup_record_candidates (ctx : infer_ctx) (key : string) :
    ty_record_info list =
  Option.value (StringMap.find_opt key ctx.record_env) ~default:[]

let record_key_of_field_names (field_names : string list) : string =
  field_names |> List.sort_uniq String.compare |> String.concat "|"

let record_key_of_record_decl_fields (fields : record_field_decl list) : string
    =
  record_key_of_field_names
    (List.map (fun (f : record_field_decl) -> f.field_name.name) fields)

let register_ty_decl (ctx : infer_ctx) (td : ty_decl) : infer_ctx =
  match td.def with
  | TTydef_Record fields ->
      let key = record_key_of_record_decl_fields fields in
      let info = { ty_decl = td; key } in
      let existing = lookup_record_candidates ctx key in
      let ty_name_env = StringMap.add td.name.name td ctx.ty_name_env in
      {
        ctx with
        record_env = StringMap.add key (info :: existing) ctx.record_env;
        ty_name_env;
      }
  | TTydef_Alias _ | TTydef_Variant _ | TTydef_Abstract -> ctx

let lookup_ty_decl_by_name (ctx : infer_ctx) (name : string) : ty_decl option =
  StringMap.find_opt name ctx.ty_name_env
