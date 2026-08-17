(* TODO: this is a temporary module and it is an over-approximation too.
   
  It is about injecting primitives external functions whenever there is an
  similar identifier in the program.

  Instead of declaring the extern function in the signature module, 
  now we could just use them.
*)

open Ast
open Types
open Syli_common

type builtin = {
  syli_name : string;
  param_tys : constant_ty list;
  ret_ty : constant_ty;
  c_name : string;
}

let builtins : builtin list =
  [
    {
      syli_name = "syli_print_i64";
      param_tys = [ Ty_Int64 ];
      ret_ty = Ty_Unit;
      c_name = "syli_print_i64";
    };
    {
      syli_name = "syli_print_f64";
      param_tys = [ Ty_Double ];
      ret_ty = Ty_Unit;
      c_name = "syli_print_f64";
    };
    {
      syli_name = "syli_print_char";
      param_tys = [ Ty_CharLit ];
      ret_ty = Ty_Unit;
      c_name = "syli_print_char";
    };
    {
      syli_name = "syli_print_str";
      param_tys = [ Ty_StringLit ];
      ret_ty = Ty_Unit;
      c_name = "syli_print_str";
    };
    {
      syli_name = "syli_print_gc_state";
      param_tys = [ Ty_Unit ];
      ret_ty = Ty_Unit;
      c_name = "syli_print_gc_state";
    };
  ]

let is_declared (ms : module_structure) (name : string) : bool =
  List.exists
    (fun (si : structure_item) ->
      match si.structure_item_desc with
      | Str_Signature sigs ->
          List.exists
            (fun (s : signature_item) ->
              match s.signature_item_desc with
              | Sig_Value { name = n; _ } -> n.name = name
              | _ -> false)
            sigs
      | _ -> false)
    ms.structure_items

let signature_item_of_builtin (b : builtin) : signature_item =
  let pos = Lexing.dummy_pos in
  let mk_ty ty_desc = Parser_helpers.mk_ty pos pos ty_desc in
  let params = List.map (fun c -> mk_ty (Ty_Constant c)) b.param_tys in
  let value_ty = mk_ty (Ty_Arrow (params, mk_ty (Ty_Constant b.ret_ty))) in
  let name = Parser_helpers.mk_ident pos pos b.syli_name in
  Parser_helpers.mk_signature_external_value pos pos name value_ty b.c_name

let inject (ms : module_structure) : module_structure =
  let used =
    Ast_visitor.collect_idents ms.structure_items |> StringSet.of_list
  in
  let to_inject =
    builtins
    |> List.filter (fun b ->
        (not (is_declared ms b.syli_name)) && StringSet.mem b.syli_name used)
    |> List.map signature_item_of_builtin
  in
  if to_inject = [] then ms
  else
    let pos = Lexing.dummy_pos in
    let sig_item =
      Parser_helpers.mk_structure_item pos pos (Str_Signature to_inject)
    in
    { ms with structure_items = sig_item :: ms.structure_items }
