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
                  [Parsing -> AST]
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

type ident = {
  name : string;
  path : path;
  id : int;
  loc : location;
  is_operator : bool;
}
(** A name paired with a path, a unique ID and source location; [is_operator]
    marks the dedicated operator namespace. *)

type mut_flag =
  | Mutable
  | Immutable  (** Mutability flag for let-bindings and record fields. *)

type rec_flag =
  | Recursive
  | NonRecursive  (** Recursion flag for let-bindings. *)

(* ========================= *)
(* Constants                 *)
(* ========================= *)

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
  | Ty_F32
  | Ty_F64
  | Ty_String
  | Ty_Char

(* ========================= *)
(* Types                     *)
(* ========================= *)

type ty = { id : int; ty_desc : ty_desc; loc : location }
(** A type node with an ID, description and source location. *)

and ty_desc =
  | Ty_Var of string  (** 'a *)
  | Ty_Any  (** _ *)
  | Ty_Constant of constant_ty
  | Ty_Arrow of ty * ty  (** T1 -> T2 *)
  | Ty_Tuple of ty list  (** (T1 * T2 * ... * Tn) *)
  | Ty_Array of ty  (** array[T] *)
  | Ty_Defined of {
      name : ident;  (** ref, option, list, etc. *)
      args : ty list;
    }

(* ========================= *)
(* Record fields             *)
(* ========================= *)

type record_field_decl = {
  id : int;
  field_name : ident;
  field_ty : ty;
  field_mut : mut_flag;
  loc : location;
}
(** A record field declaration. *)

(* ========================= *)
(* Variant constructors      *)
(* ========================= *)

type variant_constructor_decl = {
  id : int;
  name : ident;
  arg : variant_constructor_arg option;
  loc : location;
}
(** A variant constructor declaration. *)

and variant_constructor_arg =
  | Constr_ty of ty
  | Constr_record of record_field_decl list
      (** Argument of a variant constructor: a type or an inline record. *)

(* ========================= *)
(* Type declarations         *)
(* ========================= *)

type ty_decl_desc =
  | Tydef_Alias of ty
  | Tydef_Record of record_field_decl list (* Only nominal type for record *)
  | Tydef_Variant of variant_constructor_decl list
  | Tydef_Abstract  (** Body of a type declaration. *)

type ty_decl = {
  id : int;
  name : ident;
  params : ident list;
  def : ty_decl_desc;
  annotations : ident list;
  loc : location;
}
(** A full type declaration. *)

(* ======================= *)
(* Surface AST Expressions *)
(* ======================= *)

type param = { pattern : pattern; param_ty : ty option; loc : location }
(** A function parameter with optional type annotation. *)

and lambda = {
  params : param list;
  body : expr;
  ret_ty : ty option;
  loc : location;
}
(** A lambda expression. *)

and let_kind = LetVal | LetFun  (** Kind of let-binding: value or function. *)

and letdef = {
  let_kind : let_kind;
  rec_flag : rec_flag;
  pattern : pattern;
  value : expr;
  ty_annot : ty option;
  loc : location;
}
(** A let-binding; [LetFun] with a [Pat_Ident] whose name carries
    [is_operator = true] binds an operator. *)

and record_field = {
  id : int;
  field_name : ident;
  field_value : expr;
  loc : location;
}
(** A record field expression. *)

and constant_desc =
  | Const_Unit
  | Const_BoolLit of string
  | Const_IntLit of string
  | Const_FloatLit of string
  | Const_CharLit of string
  | Const_StringLit of string  (** Description of a literal constant. *)

and constant = { id : int; constant_desc : constant_desc; loc : location }
(** A literal constant. *)

and expr = { id : int; expr_desc : expr_desc; loc : location }
(** An expression node. *)

and expr_desc =
  | Exp_Constant of constant
  | Exp_Ident of ident
  | Exp_Tuple of { elements : expr list }
  | Exp_Record of { fields : record_field list }
  | Exp_VariantConstructor of { name : ident; arg : expr option }
  | Exp_Array of { element_ty : ty; elements : expr list; size : expr }
  | Exp_Lambda of lambda
  | Exp_Apply of { closure_fun : expr; args : expr list }
  | Exp_Let of letdef
  | Exp_If of {
      condition : expr;
      then_branch : expr;
      else_branch : expr option;
    }
  | Exp_While of { condition : expr; body : expr }
  | Exp_Loop of { condition : expr }
  | Exp_Break of { value : expr option }
  | Exp_Continue
  | Exp_Return of { value : expr option }
  | Exp_Seq of { exprs : expr list }
  | Exp_Match of { expr : expr; cases : pattern_case list }
  | Exp_Field of { record : expr; field_name : ident }
  | Exp_FieldSet of { record : expr; field_name : ident; value : expr }
      (** Description of an expression node. *)

and pattern_case = {
  id : int;
  pattern : pattern;
  when_condition : expr option;
  body : expr;
  loc : location;
}
(** A pattern-matching case with optional guard. *)

and pattern = { id : int; node : pattern_desc; loc : location }
(** A pattern node with ID and description. *)

and pattern_record_field = {
  id : int;
  name : ident;
  value : pattern option;
  loc : location;
}
(** A single field in a record pattern. *)

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
  | Pat_Constructor of { name : ident; value : pattern option }
  | Pat_Any  (** Description of a pattern. *)

(*============================*)
(* Signatures and structures  *)
(*============================*)

type signature_item_desc =
  | Sig_Value of { name : ident; ty : ty }
  | Sig_External of { fname : ident; ty : ty; external_fn : external_fn }
  | Sig_Type of ty_decl (* type exposed *)
  | Sig_ModuleSignature of module_signature
      (** Descriptor for a signature item. *)

and external_fn = {
  symbol : symbol;
  kind : external_kind;
  calling_convention : string option (* e.g., "ccc", "fastcc", etc. *);
}
(** An external function declaration. *)

and external_kind = Foreign | Primitive
and symbol = { name : string; loc : location }

and signature_item = {
  id : int;
  signature_item_desc : signature_item_desc;
  loc : location;
}
(** A signature item with ID and location. *)

and structure_item_desc =
  | Str_External of { fname : ident; ty : ty; external_fn : external_fn }
  | Str_Let of letdef
  | Str_Type of ty_decl (* type definition: type Foo = ... *)
  | Str_ModuleStructure of module_structure
  | Str_ModuleSignature of module_signature
      (** Descriptor for a structure item. *)

and structure_item = {
  id : int;
  structure_item_desc : structure_item_desc;
  loc : location;
}
(** A structure item with ID and location. *)

and module_signature = {
  id : int;
  name : ident;
  signature_items : signature_item list;
  loc : location;
}
(** A module signature (interface). *)

and module_structure = {
  id : int;
  name : ident;
  structure_items : structure_item list;
  loc : location;
}
(** A module structure (implementation). *)
