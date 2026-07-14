open Typed_ast
open Ast_visitor
open Syli_common

(** This is performed in order to desugarize the AST into the Core AST, which is
    a simpler AST that is easier to generate code from. This includes:
    - Collect path names for modules and functions (e.g. A.B.C.foo)
    - Collect field indices for record types (record field names to field
      indices) *)

module IdentEnv = struct
  type t = string StringMap.t

  let empty = StringMap.empty

  let lookup env x =
    match StringMap.find_opt x env with Some x' -> x' | None -> x

  let add x path env = StringMap.add x path env
end

type path_ctx = {
  renameEnv : IdentEnv.t;
  collected_paths : (int, string) Hashtbl.t;
  current_path : string list;
}

let collect_paths (prog : program) : path_ctx =
  let visitor =
    {
      default_visitor with
      expr =
        (fun v acc e ->
          match e.expr_desc with
          | TExp_Ident { name; id; _ } ->
              let _ =
                Hashtbl.add acc.collected_paths id
                  (IdentEnv.lookup acc.renameEnv name)
              in
              v.expr v acc e
          | TExp_Let { pattern; value; rec_flag; _ } ->
              let acc' =
                match pattern.pattern_desc with
                | TPat_Ident name ->
                    let path =
                      String.concat "." (List.rev acc.current_path)
                      ^ "." ^ name.name
                    in
                    Hashtbl.add acc.collected_paths e.id path;
                    let acc' =
                      { acc with current_path = name.name :: acc.current_path }
                    in
                    if rec_flag = TRecursive then
                      {
                        acc' with
                        renameEnv = IdentEnv.add name.name path acc.renameEnv;
                      }
                    else acc'
                | _ -> acc
              in
              v.expr v acc' value
          | _ -> default_expr v acc e);
      structure_item =
        (fun v acc s ->
          match s.structure_item_desc with
          | TStr_ModuleStruct { name; structure_items; _ } ->
              let path =
                String.concat "." (List.rev acc.current_path) ^ "." ^ name.name
              in
              Hashtbl.add acc.collected_paths s.id path;
              let acc' =
                { acc with current_path = name.name :: acc.current_path }
              in
              let _ =
                List.map (fun s -> v.structure_item v acc' s) structure_items
              in
              v.structure_item v acc s
          | TStr_Fun { name; body; rec_flag; _ } ->
              let path =
                String.concat "." (List.rev acc.current_path) ^ "." ^ name.name
              in
              Hashtbl.add acc.collected_paths s.id path;
              let acc' =
                if rec_flag = TRecursive then
                  {
                    acc with
                    renameEnv = IdentEnv.add name.name path acc.renameEnv;
                    current_path = name.name :: acc.current_path;
                  }
                else { acc with current_path = name.name :: acc.current_path }
              in
              let _ = v.expr v acc' body in
              acc
          | TStr_Let { pattern; value; rec_flag; _ } ->
              let acc' =
                match pattern.pattern_desc with
                | TPat_Ident name ->
                    let path =
                      String.concat "." (List.rev acc.current_path)
                      ^ "." ^ name.name
                    in
                    Hashtbl.add acc.collected_paths s.id path;
                    let acc' =
                      { acc with current_path = name.name :: acc.current_path }
                    in
                    if rec_flag = TRecursive then
                      {
                        acc' with
                        renameEnv = IdentEnv.add name.name path acc.renameEnv;
                      }
                    else acc'
                | _ -> acc
              in
              let _ = v.expr v acc' value in
              acc
          | _ -> default_structure_item v acc s);
    }
  in
  visit_program visitor
    {
      renameEnv = IdentEnv.empty;
      collected_paths = Hashtbl.create 100;
      current_path = [];
    }
    prog.structure_items

type field_ctx = { field_indices : (int, int) Hashtbl.t }

let collect_field_indices (prog : program) : field_ctx =
  let visitor =
    {
      default_visitor with
      ty =
        (fun t env ty ->
          match ty.ty_desc with
          | TTy_Defined _ -> default_ty t env ty
          | TTy_Constant _ | TTy_Var _ | TTy_Any | TTy_Arrow _ | TTy_Tuple _
          | TTy_Array _ ->
              default_ty t env ty);
      structure_item =
        (fun v env si ->
          match si.structure_item_desc with
          | TStr_TypeDef td -> (
              match td.def with
              | TTydef_Record fields ->
                  let _ =
                    List.mapi
                      (fun i (f : record_field_decl) ->
                        Hashtbl.add env.field_indices f.id i)
                      fields
                  in
                  visit_structure_item_children v env si
              | _ -> visit_structure_item_children v env si)
          | _ -> visit_structure_item_children v env si);
    }
  in
  visit_program visitor
    { field_indices = Hashtbl.create 100 }
    prog.structure_items
