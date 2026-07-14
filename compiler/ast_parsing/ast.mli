(*
  AST — Abstract Syntax Tree

  Description:
  The AST represents the high-level syntactic and semantic structure
  of the source code.

  Purpose:
  - Captures all source-level language constructs (including `let` and `while`).
  - Serves as the foundation frontend of the language and desugaring into Core AST.

  Characteristics:
  - Expression-based: every node produces a value.
  - Variables are immutable by default; `Let` introduces immutability.
  - Control flow (`If`, `While`, `Seq`, `ForIn`) is structured and scoped.
  - Functions are first-class, defined with `lambda`.

             ┌──────────────────────┐
             │   Source Language    │
             └──────────────────────┘
                        │
                  [Parsing → AST]
                        │
                        |
        (unique vars & functions, no shadowing)
                        │
              [Type Checking -> Typed AST]
                        │
                  [ Desugaring]
                        │
             ┌──────────────────────┐
             │   CORE LANGUAGE      │ (simplified, desugared)
             └──────────────────────┘
                        │
                  [Lowering]
                        │
             ┌──────────────────────┐
             │         CIR          │ (Syli Closure Intermediate Representation)
             └──────────────────────┘
                        │
                [Escape Analysis]
                (memory tier choice)
                        │
               [Optimized CIR]
                        │
                        │
             ┌──────────────────────┐
             │         OIR          │ (Syli Object Intermediate Representation)
             └──────────────────────┘
                        │
                  [Lowering]
                        │
            ┌──────────────────────┐
            │         RIR          │ (Runtime Intermediate Representation)
            └──────────────────────┘
                   /         \
                  /           \
   ┌────────────────────┐     ┌────────────────────────┐
   │  VM Bytecode Gen   │     │   Native Code Gen (via │
   │   (portable, fast) │     │   LLVM or JIT backend) │
   └────────────────────┘     └────────────────────────┘

*)

val expr_id_counter : int ref
(** Global counter for generating fresh expression/type IDs. *)

val fresh_id : unit -> int
(** Returns a fresh unique integer ID. *)

type path = string list
(** A dotted path of module names. *)

type location = { start_pos : int; end_pos : int; filename : string }
(** Source location in the input file. *)

type ident = { name : string; id : int; loc : location }
(** A name paired with a unique ID and source location. *)

(** Mutability flag for let-bindings and record fields. *)
type mut_flag = Mutable | Immutable

(** Recursion flag for let-bindings. *)
type rec_flag = Recursive | NonRecursive

(** Primitive constant types available in the language. *)
type constant_ty =
  | Ty_Int64
  | Ty_Int32
  | Ty_Int16
  | Ty_Int8
  | Ty_UInt64
  | Ty_UInt32
  | Ty_UInt16
  | Ty_UInt8
  | Ty_Bool
  | Ty_Unit
  | Ty_Float
  | Ty_Double
  | Ty_StringLit
  | Ty_CharLit

type ty = { id : int; ty_desc : ty_desc; loc : location }
(** A type node with an ID and description. *)

(** The description of a type. *)
and ty_desc =
  | Ty_Var of string
  | Ty_Any
  | Ty_Constant of constant_ty
  | Ty_Arrow of ty list * ty
  | Ty_Tuple of ty list
  | Ty_Array of ty
  | Ty_Defined of { name : ident; args : ty list }

type variant_constructor_decl = {
  id : int;
  name : ident;
  arg : ty option;
  loc : location;
}
(** A single variant constructor declaration. *)

type record_field_decl = {
  id : int;
  field_name : ident;
  field_ty : ty;
  field_mut : mut_flag;
  loc : location;
}
(** A single record field declaration. *)

(** The body of a type declaration. *)
type ty_decl_desc =
  | Tydef_Alias of ty
  | Tydef_Record of record_field_decl list
  | Tydef_Variant of variant_constructor_decl list
  | Tydef_Abstract

type ty_decl = {
  id : int;
  name : ident;
  params : string list;
  def : ty_decl_desc;
  annotations : ident list;
  loc : location;
}
(** A type declaration (alias, record, variant, or abstract). *)

(** Logical negation operator. *)
type unop_logical = Not

(** Arithmetic negation operator. *)
type unop_arithmetic = Neg

(** Bitwise negation operator. *)
type unop_bitwise = BitNot

(** Unary operator (logical, arithmetic, or bitwise). *)
type unop =
  | Unop_Logical of unop_logical
  | Unop_Arithmetic of unop_arithmetic
  | Unop_Bitwise of unop_bitwise

(** Comparison binary operators. *)
type binop_comparison = Eq | Ne | Lt | Le | Gt | Ge

(** Arithmetic binary operators. *)
type binop_arithmetic = Add | Sub | Mul | Div | Mod

(** Logical binary operators. *)
type binop_logical = And | Or

(** Bitwise binary operators. *)
type binop_bitwise = BitAnd | BitOr | BitXor | LShift | RShift

(** Binary operator (arithmetic, logical, bitwise, or comparison). *)
type binop =
  | Binop_Arithmetic of binop_arithmetic
  | Binop_Logical of binop_logical
  | Binop_Bitwise of binop_bitwise
  | Binop_Comparison of binop_comparison

(** Collection literal (list, array, map, or set). *)
type collection =
  | Col_List of expr list
  | Col_Array of expr list
  | Col_Map of (expr * expr) list
  | Col_Set of expr list

and param = {
  pattern : pattern;
  mut_flag : mut_flag;
  param_ty : ty option;
  loc : location;
}
(** A function parameter with an optional type annotation. *)

and lambda = {
  params : param list;
  body : expr;
  ret_ty : ty option;
  loc : location;
}
(** A lambda expression (anonymous function). *)

(** Kind of let-binding: value or function. *)
and let_kind = LetVal | LetFun

and letdef = {
  let_kind : let_kind;
  rec_flag : rec_flag;
  pattern : pattern;
  value : expr;
  ty_opt : ty option;
  loc : location;
}
(** A let definition (value or function binding). *)

and record_field = {
  id : int;
  field_name : string;
  field_value : expr;
  loc : location;
}
(** A single field in a record expression. *)

(** Descriptor for literal constants. *)
and constant_desc =
  | Const_Unit
  | Const_BoolLit of string
  | Const_IntLit of string
  | Const_FloatLit of string
  | Const_CharLit of string
  | Const_StringLit of string

and constant = { id : int; constant_desc : constant_desc; loc : location }
(** A literal constant with an ID and location. *)

and expr = { id : int; expr_desc : expr_desc; loc : location }
(** An expression node with an ID, description, and location. *)

(** The description of an expression. *)
and expr_desc =
  | Exp_Constant of constant
  | Exp_Ident of ident
  | Exp_Tuple of expr list
  | Exp_Record of record_field list
  | Exp_Collection of collection
  | Exp_VariantConstructor of { name : ident; arg : expr option }
  | Exp_ArrayCreate of { lambda_init : lambda; element_ty : ty; size : expr }
  (*TODO:
    Array_.. will be removed to have
    Array of { size: int; elements: expr; ty:ty}
  *)
  | Exp_ArrayLength of expr
  | Exp_ArrayGet of { arr : expr; idx : expr }
  | Exp_ArraySet of { arr : expr; idx : expr; value : expr }
  | Exp_UnOp of unop * expr
  | Exp_BinOp of binop * expr * expr
  | Exp_Lambda of lambda
  | Exp_Apply of { closure_fun : expr; args : expr list }
  | Exp_Let of letdef
  | Exp_Assign of { target : expr; value : expr }
  | Exp_If of { cond : expr; then_branch : expr; else_branch : expr option }
  | Exp_While of { cond : expr; body : expr }
  | Exp_ForIn of { iter_var : pattern; iterable : expr; body : expr }
  | Exp_Loop of expr
  | Exp_Break of expr option
  | Exp_Continue
  | Exp_Return of expr option
  | Exp_Seq of expr list
  | Exp_Match of expr * pattern_case list
  | Exp_Field of { record : expr; field_name : ident }
  | Exp_Index of { collection : expr; index : expr }

and pattern_case = {
  id : int;
  pattern : pattern;
  when_opt : expr option;
  body : expr;
  loc : location;
}
(** A pattern-matching case with an optional guard. *)

(** Collection pattern: list, array, map, or set. *)
and collection_pattern_item =
  | Pat_List of pattern list
  | Pat_Array of pattern list
  | Pat_Map of (pattern * pattern) list
  | Pat_Set of pattern list

and pattern = { id : int; node : pattern_desc; loc : location }
(** A pattern node with an ID and description. *)

(** The description of a pattern. *)
and pattern_desc =
  | Pat_Unit
  | Pat_BoolLit of string
  | Pat_IntLit of string
  | Pat_CharLit of string
  | Pat_FloatLit of string
  | Pat_StringLit of string
  | Pat_Ident of ident
  | Pat_Tuple of pattern list
  | Pat_Record of (ident * pattern option) list
  | Pat_Constructor of ident * pattern option
  | Pat_Collection of collection_pattern_item * ty option
  | Pat_Wildcard

(** Descriptor for a signature item (value, type, or module). *)
type signature_item_desc =
  | Sig_Value of {
      name : ident;
      params : ty list;
      value_ty : ty;
      external_fn : external_fn option;
    }
  | Sig_Type of ty_decl
  | Sig_Module of module_signature

and external_fn = { c_name : string; calling_convention : string option }
(** An external (FFI) function declaration. *)

and signature_item = {
  id : int;
  signature_item_desc : signature_item_desc;
  loc : location;
}
(** A signature item with an ID and location. *)

(** Descriptor for a structure item. *)
and structure_item_desc =
  | Str_Let of letdef
  | Str_Fun of {
      rec_flag : rec_flag;
      name : ident;
      body : expr;
      ty_opt : ty option;
    }
  | Str_TypeDef of ty_decl
  | Str_ModuleStruct of module_structure
  | Str_Signature of signature_item list

and structure_item = {
  id : int;
  structure_item_desc : structure_item_desc;
  loc : location;
}
(** A structure item with an ID and location. *)

and module_signature = {
  id : int;
  name : ident;
  signature_items : signature_item list;
  loc : location;
}
(** A module signature (interface) with a name and items. *)

and module_structure = {
  id : int;
  name : ident;
  structure_items : structure_item list;
  loc : location;
}
(** A module structure (implementation) with a name and items. *)
