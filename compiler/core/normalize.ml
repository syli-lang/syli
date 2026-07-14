open Core_ast
open Ast_transformer_acc
open Syli_common

module RenameEnv = struct
  type t = {
    map : string StringMap.t;
    toplevel_counts : int StringMap.t;
    toplevel_seen : int StringMap.t;
    counter : int ref;
  }

  let make_with_counts counts =
    {
      map = StringMap.empty;
      toplevel_counts = counts;
      toplevel_seen = StringMap.empty;
      counter = ref 0;
    }

  let empty = make_with_counts StringMap.empty

  let lookup env x =
    match StringMap.find_opt x env.map with Some x' -> x' | None -> x

  let fresh_var env =
   fun base ->
    incr env.counter;
    base ^ "#" ^ string_of_int !(env.counter)

  (** Rename a local binding (CExp_Let, lambda param). Renames on any shadowing;
      otherwise keeps the original name. *)
  let extend x env =
    if StringMap.mem x env.map then
      let x' = fresh_var env x in
      ({ env with map = StringMap.add x x' env.map }, x')
    else ({ env with map = StringMap.add x x env.map }, x)

  (** Rename a top-level binding (CStr_Let). The last occurrence of a name at
      the top level keeps its original name. *)
  let extend_toplevel x env =
    let seen =
      Option.value ~default:0 (StringMap.find_opt x env.toplevel_seen)
    in
    let seen' = seen + 1 in
    let total =
      Option.value ~default:1 (StringMap.find_opt x env.toplevel_counts)
    in
    let env' =
      { env with toplevel_seen = StringMap.add x seen' env.toplevel_seen }
    in
    if seen' = total then ({ env' with map = StringMap.add x x env'.map }, x)
    else
      let x' = fresh_var env x in
      ({ env' with map = StringMap.add x x' env'.map }, x')
end

let count_toplevel_bindings (prog : program_core) : int StringMap.t =
  List.fold_left
    (fun acc (item : structure_item) ->
      match item.structure_item_desc with
      | CStr_Let { name; _ } ->
          let n =
            Option.value ~default:0 (StringMap.find_opt name.fullname acc)
          in
          StringMap.add name.fullname (n + 1) acc
      | _ -> acc)
    StringMap.empty prog.structure_items

let rename_ident_use (env : RenameEnv.t) (id : ident) : ident =
  { id with fullname = RenameEnv.lookup env id.fullname }

let rename_lambda (t : RenameEnv.t transformer) (env : RenameEnv.t)
    (lam : lambda) : RenameEnv.t * lambda =
  let env = { env with counter = ref 0 } in
  let env_with_params, params' =
    List.fold_left_map
      (fun e (id : ident) ->
        let e', fullname' = RenameEnv.extend id.fullname e in
        (e', { id with fullname = fullname' }))
      env lam.params
  in
  let _, body' = t.expr t env_with_params lam.body in
  (env, { lam with params = params'; body = body' })

let rename_transformer : RenameEnv.t transformer =
  {
    ty = default_ty;
    type_decl = default_type_decl;
    signature_item = default_signature_item;
    expr =
      (fun t env e ->
        match e.node with
        | CExp_Ident idr ->
            (env, { e with node = CExp_Ident (rename_ident_use env idr) })
        | CExp_Lambda lam ->
            let env', lam' = rename_lambda t env lam in
            (env', { e with node = CExp_Lambda lam' })
        | CExp_Let { rec_flag; name; value } ->
            let _, value' = t.expr t env value in
            let env', name' = RenameEnv.extend name.fullname env in
            ( env',
              {
                e with
                node =
                  CExp_Let
                    {
                      rec_flag;
                      name = { name with fullname = name' };
                      value = value';
                    };
              } )
        | _ -> default_expr t env e);
    structure_item =
      (fun t env d ->
        match d.structure_item_desc with
        | CStr_Let { rec_flag; name; value } ->
            let _, value' = t.expr t env value in
            let env', name' = RenameEnv.extend_toplevel name.fullname env in
            ( env',
              {
                d with
                structure_item_desc =
                  CStr_Let
                    {
                      rec_flag;
                      name = { name with fullname = name' };
                      value = value';
                    };
              } )
        | _ -> default_structure_item t env d);
  }

type renamed_program = { env : RenameEnv.t; prog : program_core }

let run_env (prog : program_core) : renamed_program =
  let toplevel_counts = count_toplevel_bindings prog in
  let initial_env = RenameEnv.make_with_counts toplevel_counts in
  let env, prog = apply_program rename_transformer initial_env prog in
  { env; prog }

let run prog = (run_env prog).prog
