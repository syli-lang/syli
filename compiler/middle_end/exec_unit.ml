open Syli_ir.Rir

let _id_counter = ref 0

let fresh_id () =
  incr _id_counter;
  !_id_counter

let mk_ty (ir : ir_type) : ty = { id = fresh_id (); ty = ir }
let void_ty = mk_ty RR_Void
let i32_ty = mk_ty RR_I32
let i8ptr_ty = mk_ty (RR_Ptr RR_I8)

let mk_var (ty : ty) (name : string) : var =
  { id = fresh_id (); fullname = name; ty }

let mk_void_call (name : qualified_name) (args : operand list) : statement =
  let id = fresh_id () in
  let void_var =
    { id; fullname = "__void_" ^ string_of_int id; ty = void_ty }
  in
  {
    id = fresh_id ();
    node = RR_Call { dst = void_var; target = Direct name; args };
    ty = void_ty;
  }

let mk_block (stmts : statement list) (term : terminator_node) : block =
  let tid = fresh_id () in
  let bid = fresh_id () in
  {
    id = bid;
    label_id = 0;
    statements = stmts;
    terminator = { id = tid; node = term };
  }

let mk_fn ~name ~params ~locals ~ret_ty ~visibility (entry : block) :
    function_rir =
  {
    id = fresh_id ();
    name;
    params;
    locals;
    entry_block = entry;
    blocks = [ entry ];
    return_ty = ret_ty;
    visibility;
  }

(** [syli_modules_init()] — calls each module's [__init.{module}] in order, then
    returns void. *)
let build_modules_init (prog : program_rir) : function_rir =
  let stmts = [ mk_void_call ("__init." ^ prog.name) [] ] in
  mk_fn ~name:"syli_modules_init" ~params:[] ~locals:[] ~ret_ty:void_ty
    ~visibility:CR_Public
    (mk_block stmts (RR_Return None))

(** [syli_startup_program(argc, argv)] — generated per program.

    1) [syli_modules_init()] runs all module initialisers

    2) [entry_function()] calls the user entry point Returns the i32 result of
    the entry function. [syli_runtime_init] and [syli_runtime_shutdown] are
    called by the runtime-owned [main] in [libsyli.a] — they are not emitted
    here. *)
let build_startup_function (entry_fn : function_rir) : function_rir =
  let argc = mk_var i32_ty "argc" in
  let argv = mk_var i8ptr_ty "argv" in
  let modules_init_stmt = mk_void_call "syli_modules_init" [] in
  let result_i32 = mk_var i32_ty "__result" in
  let is_void = entry_fn.return_ty.ty = RR_Void in
  if is_void then
    let void_var = mk_var void_ty "void_main_ret" in
    let user_main_call =
      {
        id = fresh_id ();
        node =
          RR_Call { dst = void_var; target = Direct entry_fn.name; args = [] };
        ty = void_ty;
      }
    in
    mk_fn ~name:"syli_startup_program" ~params:[ argc; argv ]
      ~locals:[ void_var; result_i32 ] ~ret_ty:i32_ty ~visibility:CR_Public
      (mk_block
         [ modules_init_stmt; user_main_call ]
         (RR_Return (Some (RR_OConstant (RR_IntLit "0", i32_ty)))))
  else
    let is_i32 = entry_fn.return_ty.ty = RR_I32 in
    if is_i32 then
      let user_main_call =
        {
          id = fresh_id ();
          node =
            RR_Call
              { dst = result_i32; target = Direct entry_fn.name; args = [] };
          ty = i32_ty;
        }
      in
      mk_fn ~name:"syli_startup_program" ~params:[ argc; argv ]
        ~locals:[ result_i32 ] ~ret_ty:i32_ty ~visibility:CR_Public
        (mk_block
           [ modules_init_stmt; user_main_call ]
           (RR_Return (Some (RR_OVar result_i32))))
    else
      let dropped = mk_var entry_fn.return_ty "__dropped_main_ret" in
      let user_main_call =
        {
          id = fresh_id ();
          node =
            RR_Call { dst = dropped; target = Direct entry_fn.name; args = [] };
          ty = entry_fn.return_ty;
        }
      in
      mk_fn ~name:"syli_startup_program" ~params:[ argc; argv ]
        ~locals:[ dropped; result_i32 ] ~ret_ty:i32_ty ~visibility:CR_Public
        (mk_block
           [ modules_init_stmt; user_main_call ]
           (RR_Return (Some (RR_OConstant (RR_IntLit "0", i32_ty)))))

let entry_function_name_for_module (module_name : string) : string =
  module_name ^ ".main"

let find_function (prog : program_rir) (fn_name : qualified_name) :
    function_rir option =
  List.find_opt (fun (fn : function_rir) -> fn.name = fn_name) prog.functions

let find_main_entry_for_module (prog : program_rir) : function_rir option =
  let qualified_entry = entry_function_name_for_module prog.name in
  match find_function prog qualified_entry with
  | Some fn -> Some fn
  | None -> (
      let prefixed_qualified_entry = "syli" ^ prog.name ^ ".main" in
      match find_function prog prefixed_qualified_entry with
      | Some fn -> Some fn
      | None -> find_function prog "main")

(** [prepare_module_internal] takes a compiled module and, if it has a main
    entry point, auto-generates the [syli_modules_init] and
    [syli_startup_program] scaffolding functions and adds them to the module's
    function list. If there is no main entry point, the module is returned
    unchanged. *)
let prepare_module_internal (prog : program_rir) : program_rir =
  match find_main_entry_for_module prog with
  | Some entry_fn ->
      let modules_init_fn = build_modules_init prog in
      let startup_fn = build_startup_function entry_fn in
      { prog with functions = startup_fn :: modules_init_fn :: prog.functions }
  | None -> prog

let prepare_module (ctx : Pipeline_types.rir_ctx) : Pipeline_types.rir_ctx =
  {
    module_rir = prepare_module_internal ctx.module_rir;
    apply_gen_functions = ctx.apply_gen_functions;
  }
