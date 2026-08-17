open Types

(* Unique expression ID *)
let expr_id_counter = ref 0

let fresh_id () =
  incr expr_id_counter;
  !expr_id_counter

(* ============================================*)
(*         Syli Surface AST Definitions        *)
(* ============================================*)

(** Recursion flag for let-bindings. *)
type rec_flag = Recursive | NonRecursive

(* ======================= *)
(* Surface AST Expressions *)
(* ======================= *)

(* Unary and binary operators *)
type unop_logical = Not
type unop_arithmetic = Neg
type unop_bitwise = BitNot

type unop =
  | Unop_Logical of unop_logical
  | Unop_Arithmetic of unop_arithmetic
  | Unop_Bitwise of unop_bitwise

(* Comparison operators *)
type binop_comparison = Eq | Ne | Lt | Le | Gt | Ge

(* Arithmetic operators *)
type binop_arithmetic = Add | Sub | Mul | Div | Mod

(* Logical operators *)
type binop_logical = And | Or

(* Bitwise operators *)
type binop_bitwise = BitAnd | BitOr | BitXor | LShift | RShift

type binop =
  | Binop_Arithmetic of binop_arithmetic
  | Binop_Logical of binop_logical
  | Binop_Bitwise of binop_bitwise
  | Binop_Comparison of binop_comparison

and param = {
  pattern : pattern;
  mut_flag : mut_flag;
  param_ty : ty option;
  loc : location;
}

and lambda = {
  params : param list;
  body : expr;
  ret_ty : ty option;
  loc : location;
}

and let_kind = LetVal | LetFun

and letdef = {
  let_kind : let_kind;
  rec_flag : rec_flag;
  pattern : pattern;
  value : expr;
  ty_opt : ty option;
  loc : location;
}

and record_field = {
  id : int;
  field_name : ident;
  field_value : expr;
  loc : location;
}

and constant_desc =
  | Const_Unit
  | Const_BoolLit of string
  | Const_IntLit of string
  | Const_FloatLit of string
  | Const_CharLit of string
  | Const_StringLit of string

and constant = { id : int; constant_desc : constant_desc; loc : location }

(* Expression *)
and expr = { id : int; expr_desc : expr_desc; loc : location }

and expr_desc =
  | Exp_Constant of constant
  | Exp_Ident of ident
  | Exp_Tuple of { elements : expr list }
  | Exp_Record of { fields : record_field list }
  | Exp_VariantConstructor of { name : ident; arg : expr option }
  | Exp_ArrayCreate of { element_ty : ty; size : expr }
  | Exp_ArrayLength of { arr : expr }
  | Exp_ArrayGet of { arr : expr; idx : expr }
  | Exp_ArraySet of { arr : expr; idx : expr; value : expr }
  | Exp_UnOp of { op : unop; value : expr }
  | Exp_BinOp of { op : binop; lvalue : expr; rvalue : expr }
  | Exp_Ref of { value : expr }
  | Exp_Deref of { value : expr }
  | Exp_Lambda of lambda
  | Exp_Apply of { closure_fun : expr; args : expr list }
  | Exp_Let of letdef
  | Exp_Assign of {
      target : expr;
          (* must be an l-value: variable, field access, ref, or index *)
      value : expr;
    }
  | Exp_AssignRef of { target : expr; value : expr }
  | Exp_If of { cond : expr; then_branch : expr; else_branch : expr option }
  | Exp_While of { cond : expr; body : expr }
  | Exp_ForIn of { iter_var : pattern; iterable : expr; body : expr }
  | Exp_Loop of { expr : expr }
  | Exp_Break of { expr_opt : expr option }
  | Exp_Continue
  | Exp_Return of { expr_opt : expr option }
  | Exp_Seq of { exprs : expr list }
  | Exp_Match of { expr : expr; cases : pattern_case list }
  | Exp_Field of { record : expr; field_name : ident }
  | Exp_Index of { collection : expr; index : expr }

and pattern_case = {
  id : int;
  pattern : pattern;
  when_condition : expr option;
  body : expr;
  loc : location;
}

(* ==================== *)
(* Patterns *)
(* ==================== *)
and pattern = { id : int; node : pattern_desc; loc : location }

and pattern_record_field = {
  name : ident;
  pattern : pattern option;
  loc : location;
}

and pattern_desc =
  | Pat_Unit
  | Pat_BoolLit of string
  | Pat_IntLit of string
  | Pat_CharLit of string
  | Pat_FloatLit of string
  | Pat_StringLit of string
  | Pat_Ident of ident
  | Pat_Tuple of { elements : pattern list }
  | Pat_Record of { fields : pattern_record_field list }
  | Pat_Constructor of { name : ident; pattern : pattern option }
  | Pat_Any

(*============================*)
(* Signatures and Structures *)
(*============================*)

type signature_item_desc =
  | Sig_Value of {
      name : ident;
      (*TODO: param and value_ty need to be one entity which is value_ty*)
      params : ty list;
      value_ty : ty;
      external_fn : external_fn option;
    }
  | Sig_Type of ty_decl (* type exposed *)
  | Sig_Module of module_signature

and external_fn = {
  c_name : string; (* Actual C symbol name *)
  calling_convention : string option (* e.g., "ccc", "fastcc", etc. *);
}

and signature_item = {
  id : int;
  signature_item_desc : signature_item_desc;
  loc : location;
}

and structure_item_desc =
  | Str_Let of letdef
  | Str_Fun of {
      rec_flag : rec_flag;
      name : ident;
      body : expr; (* should be a lambda expression *)
      ty_opt : ty option;
    }
  | Str_TypeDef of ty_decl (* type definition: type Foo = ... *)
  | Str_ModuleStruct of module_structure
  | Str_Signature of signature_item list

and structure_item = {
  id : int;
  structure_item_desc : structure_item_desc;
  loc : location;
}

and module_signature = {
  id : int;
  name : ident;
  signature_items : signature_item list;
  loc : location;
}
(*
  {[
    module Helpers = sig
      val double : int -> int
    end
  ]}

  could also be a file signature "file.syi"
  > file.syi:
    val double: int -> int
    module Nested = sig
      val triple: int -> int
    end
*)

and module_structure = {
  id : int;
  name : ident;
  structure_items : structure_item list;
  loc : location;
}
(*
    {[
      module Helpers = struct
          let double = lambda x -> x * 2
      end
    ]}

  could also be a file structure "file.sy"
  > file.sy:
  {[
    signature: // self signature and could be inside file.syi
      val double: int -> int
      module Nested = sig
        val triple: int -> int
      end

    let double = lambda x -> x * 2
    module Nested = struct
      let triple = lambda x -> x * 3
    end
  ]}
*)
