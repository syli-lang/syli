open Syli_common
(** LLVM function definitions for ownership bit operations. These are appended
    to the module after lowering, so clang -O3 can inline them into call sites.
*)

open Llvm_lir.Types

let global (n : string) (ty : lltype) : operand = LV_Global (n, ty)
let local name ty = LV_Local (name, ty)
let assign dst rhs = LV_Assign (dst, rhs)
let i64_ty = LV_I64
let ptr_ty = LV_Ptr_as 1

(*
  define ptr @syli_inlinable_ownership_untag(ptr %p) {
    %i = ptrtoint ptr %p to i64
    %u = and i64 %i, -2
    %r = inttoptr i64 %u to ptr
    ret ptr %r
  }
*)
let mk_untag_fn () : func =
  {
    name = "syli_inlinable_ownership_untag";
    ret_type = ptr_ty;
    params = [ (ptr_ty, "p") ];
    blocks =
      [
        {
          label = "bb0";
          instructions =
            [
              assign (local "i" i64_ty)
                (LV_Cast (LV_PtrToInt, local "p" ptr_ty, i64_ty));
              assign (local "u" i64_ty)
                (LV_IBinOp
                   ( LV_IBitAnd,
                     local "i" i64_ty,
                     LV_Constant (LV_Integer (-2L), i64_ty) ));
              assign (local "r" ptr_ty)
                (LV_Cast (LV_IntToPtr, local "u" i64_ty, ptr_ty));
            ];
          terminator = LV_Ret (Some (local "r" ptr_ty));
        };
      ];
    linkage = Private;
    attributes = [];
  }

(*
  define ptr @syli_inlinable_ownership_borrow(ptr %p) {
    %i = ptrtoint ptr %p to i64
    %u = and i64 %i, -2
    %r = inttoptr i64 %u to ptr
    ret ptr %r
  }
*)
let mk_borrow_fn () : func =
  {
    name = "syli_inlinable_ownership_borrow";
    ret_type = ptr_ty;
    params = [ (ptr_ty, "p") ];
    blocks =
      [
        {
          label = "bb0";
          instructions =
            [
              assign (local "i" i64_ty)
                (LV_Cast (LV_PtrToInt, local "p" ptr_ty, i64_ty));
              assign (local "u" i64_ty)
                (LV_IBinOp
                   ( LV_IBitAnd,
                     local "i" i64_ty,
                     LV_Constant (LV_Integer (-2L), i64_ty) ));
              assign (local "r" ptr_ty)
                (LV_Cast (LV_IntToPtr, local "u" i64_ty, ptr_ty));
            ];
          terminator = LV_Ret (Some (local "r" ptr_ty));
        };
      ];
    linkage = Private;
    attributes = [];
  }

(*
  define void @syli_inlinable_ownership_release(ptr %p) {
    %pi = ptrtoint ptr %p to i64
    %tag = and i64 %pi, 1
    %is_own = icmp ne i64 %tag, 0
    br i1 %is_own, label %own, label %done
  own:
    call void @syli_rt_ownership_decr(ptr %p)
    ret void
  done:
    ret void
  }
*)
let mk_release_fn () : func =
  let owned_fn_ty = LV_Func ([ ptr_ty ], LV_Void) in
  {
    name = "syli_inlinable_ownership_release";
    ret_type = LV_Void;
    params = [ (ptr_ty, "p") ];
    blocks =
      [
        {
          label = "bb0";
          instructions =
            [
              assign (local "pi" i64_ty)
                (LV_Cast (LV_PtrToInt, local "p" ptr_ty, i64_ty));
              assign (local "tag" i64_ty)
                (LV_IBinOp
                   ( LV_IBitAnd,
                     local "pi" i64_ty,
                     LV_Constant (LV_Integer 1L, i64_ty) ));
              assign (local "is_own" LV_I1)
                (LV_ICmp
                   ( LV_INe,
                     local "tag" i64_ty,
                     LV_Constant (LV_Integer 0L, i64_ty) ));
            ];
          terminator = LV_CondBr (local "is_own" LV_I1, "own", "done");
        };
        {
          label = "own";
          instructions =
            [
              assign (local "_r" LV_Void)
                (LV_Call
                   {
                     fn = global "syli_rt_ownership_decr" owned_fn_ty;
                     args = [ local "p" ptr_ty ];
                     ret_ty = LV_Void;
                   });
            ];
          terminator = LV_Ret None;
        };
        { label = "done"; instructions = []; terminator = LV_Ret None };
      ];
    linkage = Private;
    attributes = [];
  }

(*
  define ptr @syli_inlinable_ownership_own(ptr %p) {
    %i = ptrtoint ptr %p to i64
    %t = and i64 %i, 1
    %is_borrow = icmp eq i64 %t, 0
    br i1 %is_borrow, label %promote, label %done
  promote:
    %r = or i64 %i, 1
    %rp = inttoptr i64 %r to ptr
    call void @syli_rt_ownership_incr(ptr %rp)
    ret ptr %rp
  done:
    ret ptr %p
  }
*)
let mk_own_fn () : func =
  let incr_fn_ty = LV_Func ([ ptr_ty ], LV_Void) in
  {
    name = "syli_inlinable_ownership_own";
    ret_type = ptr_ty;
    params = [ (ptr_ty, "p") ];
    blocks =
      [
        {
          label = "bb0";
          instructions =
            [
              assign (local "pi" i64_ty)
                (LV_Cast (LV_PtrToInt, local "p" ptr_ty, i64_ty));
              assign (local "tag" i64_ty)
                (LV_IBinOp
                   ( LV_IBitAnd,
                     local "pi" i64_ty,
                     LV_Constant (LV_Integer 1L, i64_ty) ));
              assign (local "is_borrow" LV_I1)
                (LV_ICmp
                   ( LV_IEq,
                     local "tag" i64_ty,
                     LV_Constant (LV_Integer 0L, i64_ty) ));
            ];
          terminator = LV_CondBr (local "is_borrow" LV_I1, "promote", "done");
        };
        {
          label = "promote";
          instructions =
            [
              assign (local "r" i64_ty)
                (LV_IBinOp
                   ( LV_IBitOr,
                     local "pi" i64_ty,
                     LV_Constant (LV_Integer 1L, i64_ty) ));
              assign (local "rp" ptr_ty)
                (LV_Cast (LV_IntToPtr, local "r" i64_ty, ptr_ty));
              assign (local "_inc" LV_Void)
                (LV_Call
                   {
                     fn = global "syli_rt_ownership_incr" incr_fn_ty;
                     args = [ local "rp" ptr_ty ];
                     ret_ty = LV_Void;
                   });
            ];
          terminator = LV_Ret (Some (local "rp" ptr_ty));
        };
        {
          label = "done";
          instructions = [];
          terminator = LV_Ret (Some (local "p" ptr_ty));
        };
      ];
    linkage = Private;
    attributes = [];
  }

let builtins () : func list =
  [ mk_untag_fn (); mk_borrow_fn (); mk_release_fn (); mk_own_fn () ]

let builtin_decls () : (string * lltype) list =
  [
    ("syli_rt_ownership_decr", LV_Func ([ LV_Ptr_as 1 ], LV_Void));
    ("syli_rt_ownership_incr", LV_Func ([ LV_Ptr_as 1 ], LV_Void));
  ]

let inlinable_runtime_functions =
  let open Syli_ir.Rir in
  StringMap.of_list
    [
      ( runtime_op_name_to_string RR_RT_object_borrow,
        "syli_inlinable_ownership_borrow" );
      ( runtime_op_name_to_string RR_RT_object_own,
        "syli_inlinable_ownership_own" );
      ( runtime_op_name_to_string RR_RT_object_release,
        "syli_inlinable_ownership_release" );
    ]

let use_if_inlinable_runtime_function rt_fn_name =
  let rt_fn_name = Syli_ir.Rir.runtime_op_name_to_string rt_fn_name in
  match StringMap.find_opt rt_fn_name inlinable_runtime_functions with
  | Some fn -> Some fn
  | None -> None
