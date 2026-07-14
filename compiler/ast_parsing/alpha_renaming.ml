open Ast
open Ast_transformer_acc
open Syli_common

module RenameEnv = struct
  type t = string StringMap.t

  let empty = StringMap.empty

  let lookup env x =
    match StringMap.find_opt x env with Some x' -> x' | None -> x

  let fresh_var =
    let counter = ref 0 in
    fun base ->
      incr counter;
      base ^ "#" ^ string_of_int !counter

  let extend x env =
    let x' = fresh_var x in
    (StringMap.add x x' env, x')
end

let rec bind_pattern (env : RenameEnv.t) (p : pattern) : RenameEnv.t * pattern =
  match p.node with
  | Pat_Ident x ->
      let env', x' = RenameEnv.extend x.name env in
      (env', { p with node = Pat_Ident { x with name = x' } })
  | Pat_Tuple ps ->
      let env', ps' =
        List.fold_left_map (fun e p' -> bind_pattern e p') env ps
      in
      (env', { p with node = Pat_Tuple ps' })
  | Pat_Record fields ->
      let env', fields' =
        List.fold_left_map
          (fun e (name, p_opt) ->
            match p_opt with
            | None -> (e, (name, None))
            | Some p' ->
                let e', p'' = bind_pattern e p' in
                (e', (name, Some p'')))
          env fields
      in
      (env', { p with node = Pat_Record fields' })
  | Pat_Constructor (name, p_opt) ->
      let env', p_opt' =
        match p_opt with
        | None -> (env, None)
        | Some p' ->
            let e', p'' = bind_pattern env p' in
            (e', Some p'')
      in
      (env', { p with node = Pat_Constructor (name, p_opt') })
  | Pat_Collection (Pat_List ps, ty_opt) ->
      let env', ps' =
        List.fold_left_map (fun e p' -> bind_pattern e p') env ps
      in
      (env', { p with node = Pat_Collection (Pat_List ps', ty_opt) })
  | Pat_Collection (Pat_Array ps, ty_opt) ->
      let env', ps' =
        List.fold_left_map (fun e p' -> bind_pattern e p') env ps
      in
      (env', { p with node = Pat_Collection (Pat_Array ps', ty_opt) })
  | Pat_Collection (Pat_Set ps, ty_opt) ->
      let env', ps' =
        List.fold_left_map (fun e p' -> bind_pattern e p') env ps
      in
      (env', { p with node = Pat_Collection (Pat_Set ps', ty_opt) })
  | Pat_Collection (Pat_Map kvs, ty_opt) ->
      let env', kvs' =
        List.fold_left_map
          (fun e (k, v) ->
            let e', k' = bind_pattern e k in
            let e'', v' = bind_pattern e' v in
            (e'', (k', v')))
          env kvs
      in
      (env', { p with node = Pat_Collection (Pat_Map kvs', ty_opt) })
  | Pat_Unit | Pat_BoolLit _ | Pat_IntLit _ | Pat_CharLit _ | Pat_FloatLit _
  | Pat_StringLit _ | Pat_Wildcard ->
      (env, p)

let rec rename_pattern_uses (env : RenameEnv.t) (p : pattern) : pattern =
  let node =
    match p.node with
    | Pat_Ident x -> Pat_Ident { x with name = RenameEnv.lookup env x.name }
    | Pat_Tuple ps -> Pat_Tuple (List.map (rename_pattern_uses env) ps)
    | Pat_Record fields ->
        Pat_Record
          (List.map
             (fun (n, p_opt) -> (n, Option.map (rename_pattern_uses env) p_opt))
             fields)
    | Pat_Constructor (name, p_opt) ->
        Pat_Constructor (name, Option.map (rename_pattern_uses env) p_opt)
    | Pat_Collection (Pat_List ps, ty_opt) ->
        Pat_Collection (Pat_List (List.map (rename_pattern_uses env) ps), ty_opt)
    | Pat_Collection (Pat_Array ps, ty_opt) ->
        Pat_Collection
          (Pat_Array (List.map (rename_pattern_uses env) ps), ty_opt)
    | Pat_Collection (Pat_Set ps, ty_opt) ->
        Pat_Collection (Pat_Set (List.map (rename_pattern_uses env) ps), ty_opt)
    | Pat_Collection (Pat_Map kvs, ty_opt) ->
        Pat_Collection
          ( Pat_Map
              (List.map
                 (fun (k, v) ->
                   (rename_pattern_uses env k, rename_pattern_uses env v))
                 kvs),
            ty_opt )
    | _ -> p.node
  in
  { p with node }

let rename_params (env : RenameEnv.t) (params : param list) :
    RenameEnv.t * param list =
  List.fold_left_map
    (fun e (p : param) ->
      let e', pattern' = bind_pattern e p.pattern in
      (e', { p with pattern = pattern' }))
    env params

let rename_transformer : RenameEnv.t transformer =
  {
    ty = default_ty;
    pattern =
      (fun t env p ->
        let _, p' = default_pattern t env p in
        (env, rename_pattern_uses env p'));
    expr =
      (fun t env e ->
        match e.expr_desc with
        | Exp_Ident idr ->
            let name' = RenameEnv.lookup env idr.name in
            (env, { e with expr_desc = Exp_Ident { idr with name = name' } })
        | Exp_Lambda lam ->
            let env', params' = rename_params env lam.params in
            let _, body' = t.expr t env' lam.body in
            let lam' = { lam with params = params'; body = body' } in
            (env, { e with expr_desc = Exp_Lambda lam' })
        | Exp_Let ld ->
            let _, value' = t.expr t env ld.value in
            let env', pattern' = bind_pattern env ld.pattern in
            let ld' = { ld with pattern = pattern'; value = value' } in
            (env', { e with expr_desc = Exp_Let ld' })
        | Exp_ForIn { iter_var; iterable; body } ->
            let _, iterable' = t.expr t env iterable in
            let env', iter_var' = bind_pattern env iter_var in
            let _, body' = t.expr t env' body in
            ( env,
              {
                e with
                expr_desc =
                  Exp_ForIn
                    { iter_var = iter_var'; iterable = iterable'; body = body' };
              } )
        | Exp_Match (scrutinee, cases) ->
            let _, scrutinee' = t.expr t env scrutinee in
            let cases' =
              List.map
                (fun (c : pattern_case) ->
                  let env', pattern' = bind_pattern env c.pattern in
                  let when_opt' =
                    Option.map (fun w -> snd (t.expr t env' w)) c.when_opt
                  in
                  let _, body' = t.expr t env' c.body in
                  {
                    c with
                    pattern = pattern';
                    when_opt = when_opt';
                    body = body';
                  })
                cases
            in
            (env, { e with expr_desc = Exp_Match (scrutinee', cases') })
        | _ -> default_expr t env e);
    pattern_case =
      (fun t env c ->
        let env', pattern' = bind_pattern env c.pattern in
        let when_opt' =
          Option.map (fun w -> snd (t.expr t env' w)) c.when_opt
        in
        let _, body' = t.expr t env' c.body in
        (env, { c with pattern = pattern'; when_opt = when_opt'; body = body' }));
    structure_item =
      (fun t env s ->
        match s.structure_item_desc with
        | Str_Let ld ->
            let _, value' = t.expr t env ld.value in
            let env', pattern' = bind_pattern env ld.pattern in
            let ld' = { ld with pattern = pattern'; value = value' } in
            (env', { s with structure_item_desc = Str_Let ld' })
        | Str_Fun ({ name; body; _ } as fn) ->
            let env', name' = RenameEnv.extend name.name env in
            let _, body' = t.expr t env' body in
            ( env',
              {
                s with
                structure_item_desc =
                  Str_Fun
                    { fn with name = { name with name = name' }; body = body' };
              } )
        | _ -> default_structure_item t env s);
    signature_item = default_signature_item;
    module_signature = default_module_signature;
    module_structure = default_module_structure;
  }

type alpha_renamed_program = { env : RenameEnv.t; prog : structure_item list }

let run (prog : structure_item list) : alpha_renamed_program =
  let env, prog = apply_program rename_transformer RenameEnv.empty prog in
  { env; prog }
