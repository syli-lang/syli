(** This module provides helper types and context for core AST analysis passes
    (closure analysis, lambda classification, escaping detection). *)

open Syli_common

type lambda_type = Normalun | ClosureFun
type apply_kind = FirstPartialApply | DirectApply | ClosureApply

type env_ctx = {
  lambda_names : (int, string) Hashtbl.t;
  mutable lambda_types : (int, lambda_type) Hashtbl.t;
  mutable apply_kinds : (int, apply_kind) Hashtbl.t;
  mutable escaping_functions : StringSet.t;
}
