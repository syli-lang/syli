(** Conversion from OIR to RIR (lower-level intermediate representation)

    Key transformations:
    - OIR types/operands/vars are lowered to their RIR counterparts
    - Object operations are lowered to runtime calls
    - Control flow and basic structure is preserved *)

open Syli_ir.Rir
open Syli_common
module Oir = Syli_ir.Oir
module Rir = Syli_ir.Rir

type ctx = {
  oir_var_ids : Rir.var IntMap.t (* Oir var id → Rir var with fresh Rir id *);
  block_ids : int IntMap.t (* Oir block id → Rir block id *);
}

let fresh_global_id = Oir.fresh_id

(* Helper constructors *)
let i32_ty () : Rir.ty = { id = fresh_global_id (); ty = RR_I32 }
let u32_ty () : Rir.ty = { id = fresh_global_id (); ty = RR_U32 }
let i64_ty () : Rir.ty = { id = fresh_global_id (); ty = RR_I64 }

let int_operand (value : int) : operand =
  RR_OConstant (RR_IntLit (string_of_int value), i32_ty ())

let int64_operand (value : int64) : operand =
  RR_OConstant (RR_IntLit (Int64.to_string value), i64_ty ())

let uint32_operand (value : int) : operand =
  RR_OConstant (RR_IntLit (string_of_int value), u32_ty ())

let null_operand (ty : ty) : operand = RR_OConstant (RR_Null, ty)

let void_dst () : Rir.var =
  {
    id = fresh_global_id ();
    fullname = "__sy_void";
    ty = { id = fresh_global_id (); ty = RR_Void };
  }

let is_reference_ty = function
  | RR_Bool | RR_I64 | RR_I32 | RR_I16 | RR_I8 | RR_U64 | RR_U32 | RR_U16
  | RR_U8 | RR_Float | RR_Double | RR_Void | RR_Arrow _ ->
      false
  | RR_Obj_Ptr _ -> true
  | RR_FnPtr -> false
  | RR_Char -> false
  | RR_Str -> false

(* ------------------------------------------------------------- *)
(* Object header construction                                    *)
(* Matches the C header in runtime/include/syli/header_object.h  *)
(*                                                               *)
(* Header layout (64 bits):                                      *)
(*   Bits 63-62: ZONE (2): 00=local, 01=shared, 10=static        *)
(*   Bit  61:    CYCLIC: 0=acyclic, 1=cyclic                     *)
(*   Bits 60-59: TYPE (2): 00=mono_imm, 01=mono_ref,             *)
(*                          10=mixed_order, 11=mixed_bitmap      *)
(*   Bit  58:    HasFinalizer                                    *)
(*   Bit  57:    HasPointers                                     *)
(*   Bit  56:    Tracing (0)                                     *)
(*   Bits 55-48: Variant tag (8 bits)                            *)
(*   Bits 31-0:  Payload (32 bits)                               *)
(* ------------------------------------------------------------- *)

let zone_shift = 62
let cyclic_shift = 61
let type_shift = 59
let has_pointers_shift = 57
let tracing_shift = 56
let variant_tag_shift = 48

(** ObjectType values as 2-bit fields. 00 = mono_imm, 01 = mono_ref, 10 =
    mixed_order, 11 = mixed_bitmap *)
let mono_type_of_ir_type (ty : ir_type) : int64 =
  if is_reference_ty ty then 1L else 0L

(** Variant tag shifted to bits 55-48. *)
let variant_tag_raw (tag : int) : int64 =
  Int64.shift_left (Int64.of_int tag) variant_tag_shift

(** Payload encoding kinds. *)
type payload =
  | Mono_len of { length : int }
  | Order_arity of { ptr_count : int; imm_count : int }
  | Bitmap_info of { length : int; bitmap : int }

let bitmap_of_field_types (field_types : ty list) : int =
  let rec go index acc = function
    | [] -> acc
    | (field_ty : ty) :: rest ->
        let acc' =
          if is_reference_ty field_ty.ty then acc lor (1 lsl index) else acc
        in
        go (index + 1) acc' rest
  in
  go 0 0 field_types

let ptr_and_imm_counts (field_types : ty list) : int * int =
  List.fold_left
    (fun (ptrs, imms) (field_ty : ty) ->
      if is_reference_ty field_ty.ty then (ptrs + 1, imms) else (ptrs, imms + 1))
    (0, 0) field_types

(** Assemble the full 64-bit header word using bitwise OR. *)
let make_header (zone : int64) (cyclic : int64) (obj_type : int64)
    (has_pointers : bool) (variant_tag : int64) (payload : int64) : int64 =
  let zone_bits = Int64.shift_left zone zone_shift in
  let cyclic_bits = Int64.shift_left cyclic cyclic_shift in
  let type_bits = Int64.shift_left obj_type type_shift in
  let has_pointers_bit =
    if has_pointers then Int64.shift_left 1L has_pointers_shift else 0L
  in
  let payload_bits = Int64.logand payload 0xFFFFFFFFL in
  let header = Int64.logor zone_bits cyclic_bits in
  let header = Int64.logor header type_bits in
  let header = Int64.logor header has_pointers_bit in
  let header = Int64.logor header variant_tag in
  Int64.logor header payload_bits

(** Classify a homogeneous field list (all fields are same kind: all refs or all
    imms). Returns the object type and mono-length payload if uniform. *)
let classify_mono_fields (field_types : ty list) : (int64 * payload) option =
  match field_types with
  | [] -> Some (0L, Mono_len { length = 0 })
  | first :: rest ->
      let first_kind = is_reference_ty first.ty in
      if
        List.for_all
          (fun (f : Rir.ty) -> is_reference_ty f.ty = first_kind)
          rest
      then
        let obj_type = mono_type_of_ir_type first.ty in
        Some (obj_type, Mono_len { length = List.length field_types })
      else None

(** For ordered fields (all pointers first, then immediates), use
    Type_MixedOrder (2). *)
let classify_ordered_fields (field_types : ty list) : int64 * payload =
  let ptr_count, imm_count = ptr_and_imm_counts field_types in
  (2L, Order_arity { ptr_count; imm_count })

(** For bitmap fields, use Type_MixedBitmap (3). *)
let classify_bitmap_fields (field_types : ty list) : int64 * payload =
  let length = List.length field_types in
  let bitmap = bitmap_of_field_types field_types in
  (3L, Bitmap_info { length; bitmap })

(** Encode a payload value into a 32-bit integer field. *)
let encode_payload (p : payload) : int64 =
  match p with
  | Mono_len { length } -> Int64.of_int length
  | Order_arity { ptr_count; imm_count } ->
      Int64.logor (Int64.of_int ptr_count)
        (Int64.shift_left (Int64.of_int imm_count) 16)
  | Bitmap_info { length; bitmap } ->
      Int64.logor (Int64.of_int length)
        (Int64.shift_left (Int64.of_int bitmap) 5)

(** Check if all pointer/reference fields come before any immediate field. *)
let fields_are_ordered (field_types : ty list) : bool =
  fst
    (List.fold_left
       (fun (ordered, seen_imm) (f : Rir.ty) ->
         if is_reference_ty f.ty then (ordered && not seen_imm, seen_imm)
         else (ordered, true))
       (true, false) field_types)

(** Determine whether any field is a pointer/reference type. *)
let has_pointer_fields (field_types : ty list) : bool =
  List.exists (fun (f : Rir.ty) -> is_reference_ty f.ty) field_types

(** Compute an object header operand from an OIR object_layout and its lowered
    field types. *)
let header_operand_of_layout (layout : Oir.object_layout)
    (field_types : ty list) : operand =
  let zone = 0L in
  let cyclic = 1L in
  let variant_tag =
    match layout with
    | Oir.OR_Record { tag_variant; _ } | Oir.OR_Array { tag_variant; _ } ->
        variant_tag_raw tag_variant
  in
  let has_pointers = has_pointer_fields field_types in
  let obj_type, payload =
    match classify_mono_fields field_types with
    | Some (ty, p) -> (ty, p)
    | None ->
        if fields_are_ordered field_types then
          classify_ordered_fields field_types
        else classify_bitmap_fields field_types
  in
  let payload_val = encode_payload payload in
  let header =
    make_header zone cyclic obj_type has_pointers variant_tag payload_val
  in
  int64_operand header

let rec lower_ir_type (t : Oir.ir_type) : Rir.ir_type =
  match t with
  | OR_Bool -> RR_Bool
  | OR_I64 -> RR_I64
  | OR_I32 -> RR_I32
  | OR_I16 -> RR_I16
  | OR_I8 -> RR_I8
  | OR_U64 -> RR_U64
  | OR_U32 -> RR_U32
  | OR_U16 -> RR_U16
  | OR_U8 -> RR_U8
  | OR_Float -> RR_Float
  | OR_Double -> RR_Double
  | OR_FnPtr -> RR_FnPtr
  | OR_Obj _ -> object_ptr_ty
  | OR_Obj_Ptr inner -> RR_Obj_Ptr (lower_ir_type inner.ir_type)
  | OR_Char -> RR_Char
  | OR_Str -> RR_Str
  | OR_Void -> RR_Void

let lower_ty (t : Oir.ty) : Rir.ty =
  { id = fresh_global_id (); ty = lower_ir_type t.ir_type }

let lower_var (ctx : ctx) (v : Oir.var) : ctx * Rir.var =
  match IntMap.find_opt v.id ctx.oir_var_ids with
  | Some v' -> (ctx, v')
  | None ->
      let id = fresh_id () in
      let v' = { id; fullname = v.name; ty = lower_ty v.ty } in
      ( {
          oir_var_ids = IntMap.add v.id v' ctx.oir_var_ids;
          block_ids = ctx.block_ids;
        },
        v' )

let lower_constant (c : Oir.constant) : Rir.constant =
  match c with
  | OR_IntLit s -> RR_IntLit s
  | OR_FloatLit s -> RR_FloatLit s
  | OR_BoolLit s -> RR_BoolLit s
  | OR_Null -> RR_Null
  | OR_StringLit s -> RR_StringLit s
  | OR_CharLit s -> RR_CharLit s

let lower_operand (ctx : ctx) (op : Oir.operand) : ctx * Rir.operand =
  match op with
  | OR_OConstant (c, ty) -> (ctx, RR_OConstant (lower_constant c, lower_ty ty))
  | OR_OVar v ->
      let ctx, v' = lower_var ctx v in
      (ctx, RR_OVar v')

let lower_binop (op : Oir.binop) : Rir.binop =
  match op with
  | OR_Add -> CR_Add
  | OR_Sub -> CR_Sub
  | OR_Mul -> CR_Mul
  | OR_Div -> CR_Div
  | OR_Mod -> CR_Mod
  | OR_Eq -> CR_Eq
  | OR_Ne -> CR_Ne
  | OR_Lt -> CR_Lt
  | OR_Le -> CR_Le
  | OR_Gt -> CR_Gt
  | OR_Ge -> CR_Ge
  | OR_BitAnd -> CR_BitAnd
  | OR_BitOr -> CR_BitOr
  | OR_BitXor -> CR_BitXor
  | OR_Shl -> CR_Shl
  | OR_Shr -> CR_Shr
  | OR_And -> CR_And
  | OR_Or -> CR_Or

let lower_unop (op : Oir.unop) : Rir.unop =
  match op with OR_Neg -> CR_Neg | OR_Not -> CR_Not | OR_BitNot -> CR_BitNot

let lower_visibility (v : Oir.visibility) : Rir.visibility =
  match v with OR_Public -> CR_Public | OR_Private -> CR_Private

let lower_call_target (ctx : ctx) (t : Oir.call_target) : ctx * Rir.call_target
    =
  match t with
  | Direct name -> (ctx, Direct name)
  | Direct_fn_ptr { ptr = v } ->
      let ctx, v' = lower_var ctx v in
      (ctx, Indirect v')

let lower_terminator (ctx : ctx) (term : Oir.terminator) : ctx * Rir.terminator
    =
  let lookup_block id =
    match IntMap.find_opt id ctx.block_ids with
    | Some id' -> id'
    | None -> failwith ("lower_terminator: unknown block id " ^ string_of_int id)
  in
  let ctx, node =
    match term.node with
    | OR_Goto id -> (ctx, RR_Goto (lookup_block id))
    | OR_Switch { scrutinee; cases; default_block } ->
        let ctx, scrutinee' = lower_var ctx scrutinee in
        ( ctx,
          RR_Switch
            {
              scrutinee = scrutinee';
              cases =
                List.map
                  (fun (c : Oir.switch_case_node) ->
                    {
                      Rir.value = c.value;
                      target_block = lookup_block c.target_block;
                    })
                  cases;
              default_block = Option.map lookup_block default_block;
            } )
    | OR_CondBr { cond; then_block; else_block } ->
        let ctx, cond' = lower_var ctx cond in
        ( ctx,
          RR_CondBr
            {
              cond = cond';
              then_block = lookup_block then_block;
              else_block = lookup_block else_block;
            } )
    | OR_Return op ->
        let ctx, op' =
          match op with
          | Some o ->
              let ctx, o' = lower_operand ctx o in
              (ctx, Some o')
          | None -> (ctx, None)
        in
        (ctx, RR_Return op')
  in
  (ctx, { id = fresh_global_id (); node })

let lower_field_types (field_types : Oir.ty list) : Rir.ty list =
  List.map lower_ty field_types

let runtime_call_of_object_create (dst : Rir.var) (size : Rir.operand)
    (layout : Oir.object_layout) : Rir.runtime_call =
  let field_types =
    match layout with
    | Oir.OR_Record { field_types; _ } -> lower_field_types field_types
    | Oir.OR_Array { element_ty; _ } -> [ lower_ty element_ty ]
  in
  let header = header_operand_of_layout layout field_types in
  {
    fn_name = RR_RT_rc_alloc_object;
    args = [ header; int_operand 1; size ];
    ret_ty = Some dst.ty;
  }

let rvalue_of_oir (ctx : ctx) (rv : Oir.rvalue) : ctx * Rir.rvalue =
  let rir_ty = lower_ty rv.ty in
  let ctx, node =
    match rv.node with
    | OR_BinOp { op; lhs; rhs } ->
        let ctx, lhs' = lower_operand ctx lhs in
        let ctx, rhs' = lower_operand ctx rhs in
        (ctx, RR_BinOp { op = lower_binop op; lhs = lhs'; rhs = rhs' })
    | OR_UnOp { op; operand } ->
        let ctx, operand' = lower_operand ctx operand in
        (ctx, RR_UnOp { op = lower_unop op; operand = operand' })
    | OR_Object_get { obj; field_idx; value_ty } ->
        let ctx, obj' = lower_operand ctx obj in
        let ctx, field_idx' = lower_operand ctx field_idx in
        ( ctx,
          RR_Object_load
            { obj = obj'; field_idx = field_idx'; value_ty = lower_ty value_ty }
        )
    | OR_Object_length { obj } ->
        let ctx, obj' = lower_operand ctx obj in
        ( ctx,
          RR_Runtime_call
            {
              fn_name = RR_RT_get_object_length;
              args = [ obj' ];
              ret_ty = Some rir_ty;
            } )
    | OR_Object_get_tag { obj } ->
        let ctx, obj' = lower_operand ctx obj in
        ( ctx,
          RR_Runtime_call
            {
              fn_name = RR_RT_get_object_tag;
              args = [ obj' ];
              ret_ty = Some rir_ty;
            } )
    | OR_Cast { src; to_ty } ->
        let ctx, src' = lower_operand ctx src in
        (ctx, RR_Cast { src = src'; to_ty = lower_ty to_ty })
    | OR_Move _ -> failwith "OR_Move must be lowered through statement_of_oir"
    | OR_Addr_fn { fn } -> (ctx, RR_Addr_fn { fn })
  in
  (ctx, { id = fresh_global_id (); node; ty = rir_ty })

let statement_of_oir (ctx : ctx) (stmt : Oir.statement) :
    ctx * Rir.statement list =
  match stmt.node with
  | OR_Assign { dst; rvalue = { node = OR_Move { src }; _ } } ->
      let ctx, dst' = lower_var ctx dst in
      let ctx, src' = lower_operand ctx src in
      ( ctx,
        [
          {
            id = fresh_global_id ();
            node = RR_Move { dst = dst'; src = src' };
            ty = lower_ty stmt.ty;
          };
        ] )
  | OR_Assign { dst; rvalue } ->
      let ctx, dst' = lower_var ctx dst in
      let ctx, rv' = rvalue_of_oir ctx rvalue in
      ( ctx,
        [
          {
            id = fresh_global_id ();
            node = RR_Assign { dst = dst'; rvalue = rv' };
            ty = lower_ty stmt.ty;
          };
        ] )
  | OR_Object_set { obj; field_idx; value; value_ty } ->
      let ctx, obj' = lower_var ctx obj in
      let ctx, field_idx' = lower_operand ctx field_idx in
      let ctx, value' = lower_operand ctx value in
      ( ctx,
        [
          {
            id = fresh_global_id ();
            node =
              RR_Object_store
                {
                  obj = RR_OVar obj';
                  field_idx = field_idx';
                  value = value';
                  value_ty = lower_ty value_ty;
                };
            ty = lower_ty stmt.ty;
          };
        ] )
  | OR_Object_create { dst; size; layout } ->
      let ctx, dst' = lower_var ctx dst in
      let ctx, size' = lower_operand ctx size in
      ( ctx,
        [
          {
            id = fresh_global_id ();
            node =
              RR_Runtime_call
                {
                  dst = dst';
                  call = runtime_call_of_object_create dst' size' layout;
                };
            ty = lower_ty stmt.ty;
          };
        ] )
  | OR_Call { dst; target; args } ->
      let ctx, dst' = lower_var ctx dst in
      let ctx, target' = lower_call_target ctx target in
      let ctx, args' =
        List.fold_left_map (fun ctx a -> lower_operand ctx a) ctx args
      in
      ( ctx,
        [
          {
            id = fresh_global_id ();
            node = RR_Call { dst = dst'; target = target'; args = args' };
            ty = lower_ty stmt.ty;
          };
        ] )
  | OR_RC_op { op; obj } ->
      let ctx, obj' = lower_var ctx obj in
      let fn_name =
        match op with
        | OR_RC_incr -> RR_RT_object_incr
        | OR_RC_decr -> RR_RT_object_decr
        | OR_RC_check_release -> RR_RT_object_check_release
        | OR_RC_check_drop -> RR_RT_object_check_drop
        | OR_RC_check_lost_cyclic_release ->
            RR_RT_object_check_lost_cyclic_release
        | OR_RC_check_lost_cyclic_drop -> RR_RT_object_check_lost_cyclic_drop
      in
      ( ctx,
        [
          {
            id = fresh_global_id ();
            node =
              RR_Runtime_call
                {
                  dst = void_dst ();
                  call = { fn_name; args = [ RR_OVar obj' ]; ret_ty = None };
                };
            ty = lower_ty stmt.ty;
          };
        ] )
  | OR_GC_cycle ->
      ( ctx,
        [
          {
            id = fresh_global_id ();
            node =
              RR_Runtime_call
                {
                  dst = void_dst ();
                  call = { fn_name = RR_RT_gc_cycle; args = []; ret_ty = None };
                };
            ty = lower_ty stmt.ty;
          };
        ] )
  | OR_Store_global { global; value } ->
      let ctx, value' = lower_operand ctx value in
      ( ctx,
        [
          {
            id = fresh_global_id ();
            node = RR_Store_global { global; value = value' };
            ty = lower_ty stmt.ty;
          };
        ] )
  | OR_Nop ->
      ( ctx,
        [ { id = fresh_global_id (); node = RR_Nop; ty = lower_ty stmt.ty } ] )

let block_of_oir (ctx : ctx) (block : Oir.block) : ctx * Rir.block =
  let fresh_id =
    match IntMap.find_opt block.id ctx.block_ids with
    | Some id -> id
    | None ->
        failwith
          ("block_of_oir: block not pre-registered: " ^ string_of_int block.id)
  in
  let ctx, statements =
    List.fold_left_map
      (fun ctx stmt ->
        let ctx, stmts = statement_of_oir ctx stmt in
        (ctx, stmts))
      ctx block.statements
  in
  let ctx, terminator = lower_terminator ctx block.terminator in
  ( ctx,
    {
      id = fresh_id;
      label_id = block.label_id;
      statements = List.concat statements;
      terminator;
    } )

let function_of_oir (ctx : ctx) (fn : Oir.function_oir) : ctx * Rir.function_rir
    =
  (* Reset per-function state: variables and block IDs are scoped to one function *)
  let ctx = { oir_var_ids = IntMap.empty; block_ids = IntMap.empty } in
  let ctx, params =
    List.fold_left_map (fun ctx p -> lower_var ctx p) ctx fn.params
  in
  let ctx, locals =
    List.fold_left_map (fun ctx l -> lower_var ctx l) ctx fn.locals
  in
  (* Pre-register all block IDs so terminators can reference blocks not yet lowered *)
  let ctx =
    List.fold_left
      (fun ctx (b : Oir.block) ->
        let fresh_id = fresh_global_id () in
        { ctx with block_ids = IntMap.add b.id fresh_id ctx.block_ids })
      ctx fn.blocks
  in
  let ctx, blocks =
    List.fold_left_map (fun ctx b -> block_of_oir ctx b) ctx fn.blocks
  in
  let entry_block =
    match
      List.filter
        (fun (b : Rir.block) -> b.label_id = fn.entry_block.label_id)
        blocks
    with
    | b :: _ -> b
    | [] -> failwith "function_of_oir: entry block not found in fn.blocks"
  in
  ( ctx,
    {
      id = fresh_global_id ();
      name = fn.name;
      params;
      locals;
      entry_block;
      blocks;
      return_ty = lower_ty fn.return_ty;
      visibility = lower_visibility fn.visibility;
    } )

let lower_ffi_external_function (ffi : Oir.ffi_external_function) :
    Rir.ffi_external_function =
  {
    name = ffi.name;
    syli_name = ffi.syli_name;
    ret_ty = lower_ty ffi.ret_ty;
    params = List.map lower_ty ffi.params;
    calling_convention = ffi.calling_convention;
  }

let lower_global_value (gv : Oir.global_value) : Rir.global_value =
  {
    name = gv.name;
    init_fn_name = gv.init_fn.name;
    value = lower_constant gv.value;
    ty = lower_ty gv.ty;
    visibility = lower_visibility gv.visibility;
  }

let lower (ctx : Pipeline_types.oir_ctx) : Pipeline_types.rir_ctx =
  let prog = ctx.module_oir in
  let lowering_ctx : ctx =
    { oir_var_ids = IntMap.empty; block_ids = IntMap.empty }
  in
  let _, rir_functions =
    List.fold_left_map
      (fun ctx' fn -> function_of_oir ctx' fn)
      lowering_ctx prog.functions
  in
  let _, rir_apply =
    List.fold_left_map
      (fun ctx' fn -> function_of_oir ctx' fn)
      lowering_ctx ctx.apply_gen_functions
  in
  {
    module_rir =
      {
        name = prog.name;
        type_defs = List.map (fun (n, ty) -> (n, lower_ty ty)) prog.type_defs;
        functions = rir_functions;
        global_values = List.map lower_global_value prog.global_values;
        ffi_external_functions =
          List.map lower_ffi_external_function prog.ffi_external_functions;
      };
    apply_gen_functions = rir_apply;
  }
