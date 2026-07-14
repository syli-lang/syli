(*  Syli IR aka SIR - Syli Intermediate Representation
  ====================================

  The calling convention:

    - Representation:
        A closure is a heap-allocated object storing:
          [0] accum function pointer (a generated trampoline)
          [1+] captured arguments (or dispatch metadata for chain nodes)

    - Make_closure:
        Creates an object with the accum function in field 0 and captured
        arguments starting at field 1. The accum function is a generated
        trampoline that loads stored args, receives remaining args, and
        either calls the wrapper directly (single dispatch) or dispatches
        through a switch (multi-path dispatch).

    - Partial_apply:
        Creates a chain node with layout:
          [0] accum function pointer
          [1] dispatch edge weight (if node_has_dispatch)
          [2] parent closure pointer
          [3+] new arguments
        The accum function loads the dispatch edge from field 1 (if present),
        adds it to the incoming dispatch ID, loads the parent's accum, and
        chains to it.

    - Apply:
        Loads the accum function pointer from the closure's field 0 and
        calls it with (remaining_args..., closure_ptr, dispatch_id).
        The dispatch_id is the edge weight from the closure to the apply
        destination.

    - Dispatch mechanism:
        Each call site passes a dispatch ID. Partial/cast nodes add their
        own edge weight to this ID. The root accum switches on the
        accumulated ID to select the correct wrapper case.

    - Calls:
        * Direct call:
            - Call the monomorphized function directly by name.
        * Indirect call:
            - Load the accum function pointer and call it.
            - The accum handles casting, dispatch, and calls the
              wrapper by name.
        * Wrapper:
            - A generated named function that casts i64 args to the
              expected types and calls the real monomorphized function
              by name. Not stored in the closure.

    - Notes:
        - Only the accum function pointer is stored in the closure.
          The wrapper and the real function are named functions called
          via Direct targets.
        - The dispatch ID accumulates across chain nodes and selects
          the correct case at the root switch.
        - Generic nodes (varying return types) fall back to i64 as a
          universal carrier with result casts.
*)

(* Unique identifiers *)
type id = int

type qualified_name =
  string (* "Module.fn_name", "Module.fn_name.var", "Module.var" *)

let expr_id_counter = ref 0

let fresh_id () =
  incr expr_id_counter;
  !expr_id_counter

type mut_flag = Mutable | Immutable

type binop =
  | CR_Add
  | CR_Sub
  | CR_Mul
  | CR_Div
  | CR_Mod
  | CR_Eq
  | CR_Ne
  | CR_Lt
  | CR_Le
  | CR_Gt
  | CR_Ge
  | CR_BitAnd
  | CR_BitOr
  | CR_BitXor
  | CR_Shl
  | CR_Shr
  | CR_And
  | CR_Or

type unop = CR_Neg | CR_Not | CR_BitNot
type visibility = CR_Public | CR_Private

(* SIR type system *)
type ir_type =
  | CR_Bool
  | CR_I64
  | CR_I32
  | CR_I16
  | CR_I8
  | CR_U64
  | CR_U32
  | CR_U16
  | CR_U8
  | CR_Float (* 32-bit float *)
  | CR_Double (* 64-bit float *)
  | CR_FnPtr
  | CR_Obj of { named : string option; args : ty list }
  | CR_Ptr of ty
  | CR_Void
  | CR_GenericTyp of { type_var : int }
  | CR_Arrow of ty list * ty (* (T, T, ...) -> T *)

and ty = { id : int; ir_type : ir_type }

type constant =
  | CR_IntLit of string
  | CR_FloatLit of string
  | CR_BoolLit of string
  | CR_StringLit of string
  | CR_CharLit of string
  | CR_Null

type object_layout =
  | CR_Record of { field_count : int; field_types : ty list; tag_variant : int }
  | CR_Array of { element_ty : ty; tag_variant : int }

and var = { id : id; name : string; ty : ty }
and operand = CR_OConstant of constant * ty | CR_OVar of var

and call_target =
  | Direct of qualified_name
  | Direct_fn_ptr of { ptr : var }
  | Apply of { closure : var }

type terminator = { id : int; node : terminator_node }

and terminator_node =
  | CR_Goto of id
  | CR_Switch of {
      scrutinee : var;
      cases : switch_case_node list;
      default_block : id option;
    }
  | CR_CondBr of { cond : var; then_block : id; else_block : id }
  | CR_Return of operand option

and switch_case_node = { value : int; target_block : id }

type rvalue_node =
  | CR_BinOp of { op : binop; lhs : operand; rhs : operand }
  | CR_UnOp of { op : unop; operand : operand }
  | CR_Object_get of { obj : operand; field_idx : operand; value_ty : ty }
  | CR_Object_length of { obj : operand }
  | CR_Object_get_tag of { obj : operand }
  | CR_Cast of { src : operand; to_ty : ty }
  | CR_Move of { src : operand }
      (** Move is used to assign more than once the same variables with
          alternative branches *)
  | CR_Addr_fn of { fn : qualified_name }
      (** Materialize the address of a known function as a pointer value *)

type rvalue = { id : int; node : rvalue_node; ty : ty }
and statement = { id : int; node : statement_node; ty : ty }

and statement_node =
  | CR_Assign of { dst : var; rvalue : rvalue }  (** Assignment *)
  | CR_Object_set of {
      obj : var;
      field_idx : operand;
      value : operand;
      value_ty : ty;
    }  (** Object *)
  | CR_Object_create of {
      dst : var;
      size : operand;
      layout : object_layout;
      initializer_fn : qualified_name option;
    }  (** Create a new object with the given layout and size (for arrays) *)
  | CR_Call of { dst : var; target : call_target; args : operand list }
  | CR_Make_closure of {
      dst : var;
      free_vars : var list;
      captured_args : operand list;
      fn : qualified_name;
      initializer_fn : qualified_name option;
    }
    (* CR_Make_closure: could be optimize by creating the whole closure
          object in one go without separate creating only the for the current
          varables. *)
  | CR_Partial_apply of {
      dst : var;
      closure : var;  (** the existing closure being extended *)
      new_args : operand list;  (** new arguments being partially applied *)
    }
  | CR_Store_global of { global : qualified_name; value : operand }
      (** Store to a global variable *)
  | CR_Nop  (** Nop *)

type block = {
  id : id;
  label_id : id;  (** Local block ID scoped to the containing function *)
  statements : statement list;
  terminator : terminator;
  pred_blocks : block list;
  succ_blocks : block list;
}

type function_cir = {
  id : id;
  name : qualified_name;
  params : var list;
  locals : var list;
  entry_block : block;
  blocks : block list;
  return_ty : ty;
  visibility : visibility;
}

(* External function declaration *)
type ffi_external_function = {
  name : string;  (** C name used for linking (e.g., "syli_print_i64") *)
  syli_name : string;
      (** Qualified Syli name (e.g., "syliTest_binary.syli_print_i64") *)
  ret_ty : ty;
  params : ty list;
  calling_convention : string option (* e.g., "ccc", "fastcc", etc. *);
}

type global_value = {
  name : qualified_name;
  init_fn : function_cir;
  value : constant;
  ty : ty;
  visibility : visibility;
}
(** A global value in CIR form. *)

type module_cir = {
  name : string;
  type_defs : (string * ty) list;
  functions : function_cir list;
  global_values : global_value list;
  ffi_external_functions : ffi_external_function list;
}
(** A complete CIR module. *)
