(* ==================================== *)
(* Typed AST for Syli                   *)
(* ==================================== *)

(* Type-building definitions (path, location, ident, ty, ty_decl, ...) are
   shared with the parsing AST, see [Syli_parsing.Types]. *)
include Syli_parsing.Types

type rec_flag = TRecursive | TNonRecursive
type unop_logical = TNot
type unop_arithmetic = TNeg
type unop_bitwise = TBitNot

type unop =
  | TUnop_Logical of unop_logical
  | TUnop_Arithmetic of unop_arithmetic
  | TUnop_Bitwise of unop_bitwise

type binop_comparison = TEq | TNe | TLt | TLe | TGt | TGe
type binop_arithmetic = TAdd | TSub | TMul | TDiv | TMod
type binop_logical = TAnd | TOr
type binop_bitwise = TBitAnd | TBitOr | TBitXor | TLShift | TRShift

type binop =
  | TBinop_Arithmetic of binop_arithmetic
  | TBinop_Logical of binop_logical
  | TBinop_Bitwise of binop_bitwise
  | TBinop_Comparison of binop_comparison

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

and let_kind = TLetVal | TLetFun

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
  | TConst_Unit
  | TConst_BoolLit of string
  | TConst_IntLit of string
  | TConst_FloatLit of string
  | TConst_CharLit of string
  | TConst_StringLit of string

and constant = { id : int; constant_desc : constant_desc; loc : location }
and expr = { id : int; expr_desc : expr_desc; loc : location; ty : ty }

and expr_desc =
  | TExp_Constant of constant
  | TExp_Ident of ident
  | TExp_Tuple of { elements : expr list }
  | TExp_Record of { fields : record_field list }
  | TExp_VariantConstructor of { name : ident; args : expr option }
  | TExp_ArrayCreate of { element_ty : ty; size : expr }
  | TExp_ArrayLength of { arr : expr }
  | TExp_ArrayGet of { arr : expr; idx : expr }
  | TExp_ArraySet of { arr : expr; idx : expr; value : expr }
  | TExp_UnOp of { op : unop; value : expr }
  | TExp_BinOp of { op : binop; lvalue : expr; rvalue : expr }
  | TExp_Ref of { value : expr }
  | TExp_Deref of { value : expr }
  | TExp_Lambda of lambda
  | TExp_Apply of { closure_fun : expr; args : expr list }
  | TExp_Let of letdef
  | TExp_Assign of { target : expr; value : expr }
  | TExp_AssignRef of { target : expr; value : expr }
  | TExp_If of { cond : expr; then_branch : expr; else_branch : expr option }
  | TExp_While of { cond : expr; body : expr }
  | TExp_ForIn of { iter_var : pattern; iterable : expr; body : expr }
  | TExp_Loop of { expr : expr }
  | TExp_Break of { expr_opt : expr option }
  | TExp_Continue
  | TExp_Return of { expr_opt : expr option }
  | TExp_Seq of { exprs : expr list }
  | TExp_Match of { expr : expr; cases : pattern_case list }
  | TExp_Field of { record : expr; field_name : string; idx : int }
  | TExp_Index of { collection : expr; index : expr }

and pattern_case = {
  id : int;
  pattern : pattern;
  when_condition : expr option;
  body : expr;
  loc : location;
  ty : ty;
}

and pattern = { id : int; pattern_desc : pattern_desc; loc : location; ty : ty }

and pattern_record_field = {
  name : ident;
  pattern : pattern option;
  loc : location;
}

and pattern_desc =
  | TPat_Unit
  | TPat_BoolLit of string
  | TPat_IntLit of string
  | TPat_CharLit of string
  | TPat_StringLit of string
  | TPat_FloatLit of string
  | TPat_Ident of ident
  | TPat_Tuple of { elements : pattern list }
  | TPat_Record of { fields : pattern_record_field list }
  | TPat_Constructor of { ident : string; pattern : pattern option }
  | TPat_Any

type signature_item_desc =
  | TSig_Fun of {
      name : ident;
      params : ty list;
      ret_ty : ty;
      external_fn : external_fn option;
    }
  | TSig_Type of ty_decl (* type exposed *)
  | TSig_Module of module_signature

and external_fn = {
  c_name : string; (* Actual C symbol name *)
  calling_convention : string option (* e.g., "ccc", "fastcc", etc. *);
  loc : location;
}

and signature_item = {
  id : int;
  signature_item_desc : signature_item_desc;
  loc : location;
}

and structure_item_desc =
  | TStr_Let of letdef
  | TStr_Fun of {
      rec_flag : rec_flag;
      name : ident;
      body : expr; (* should be a lambda expression *)
      ty_opt : ty option;
    }
  | TStr_TypeDef of ty_decl (* type definition: type Foo = ... *)
  | TStr_ModuleStruct of module_structure
  | TStr_Signature of signature_item list

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

and module_structure = {
  id : int;
  name : ident;
  structure_items : structure_item list;
  loc : location;
}

type program = module_structure
