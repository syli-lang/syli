(** This module provides type substitution maps and operations for the type
    inference system. *)

open Syli_common

type t = Typed_ast.ty IntMap.t

val empty : 'a IntMap.t
val bind : IntMap.key -> 'a -> 'a IntMap.t -> 'a IntMap.t
val apply : t -> Typed_ast.ty -> Typed_ast.ty
val compose : t -> t -> t
