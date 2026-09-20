%{
  open Parser_helpers
  open Ast
%}

%token <string> INT
%token <string> IDENT UIDENT STRING
%token <string> CHAR
%token <string> FLOAT
%token <string> BOOL_VAL
%token TY_INT64 TY_INT32 TY_INT16 TY_INT8 TY_UINT64 TY_UINT32 TY_UINT16 TY_UINT8
%token TY_CHAR TY_BOOL TY_UNIT TY_STRING TY_ARRAY TY_F32 TY_F64
%token REC LET RETURN IF ELSE ELSEIF THEN FUN
%token VAL FOREIGN SIGNATURE PRIMITIVE
%token WHILE LOOP DO END CONTINUE BREAK MATCH WITH TYPE OF MUTABLE WHEN
%token LPAREN RPAREN LBRACKET RBRACKET LBRACE RBRACE LBRACKET_BAR RBRACKET_BAR
%token COMMA SEMI COLON COLONEQ NEWLINE DOT ARROW
%token EQ PLUS MINUS STAR PERCENT SLASH TIMES
%token LT GT EQEQ BANGEQ LTEQ GTEQ AMPAMPAND NOT
%token BARBAR BAR CARET BANG UNDERSCORE
%token INDENT DEDENT EOF
%token STRUCTURE
%token <int> SPACE

%start <Ast.module_structure> module_structure
%start <Ast.module_structure> module_file_sy
%start <Ast.module_signature> module_signature
%start <Ast.module_signature> module_file_syi

%type <Ast.expr> expr
%type <Ast.param list> params
%type <Ast.ty> ty
%type <Ast.ty_decl> type_def
%type <Ast.variant_constructor_decl> ty_constructor_decl

%right ARROW
%nonassoc COLONEQ
%left BARBAR
%left AMPAMPAND
%left GT LT GTEQ LTEQ EQEQ BANGEQ
%left PLUS MINUS
%left TIMES PERCENT SLASH

%nonassoc BANG

%%

term_end:
  | DEDENT { () }
  | DEDENT END { () }

module_file_sy:
  | structure_items EOF
      {
        mk_module_struct $startpos $endpos (mk_ident $startpos $endpos "") $1
      }

module_file_syi:
  | signature_items EOF
      {
        mk_module_signature $startpos $endpos (mk_ident $startpos $endpos "")
          $1
      }

module_structure:
  | STRUCTURE name = uident NEWLINE INDENT structure_items term_end
    { mk_module_struct $startpos $endpos name $5 }

module_signature:
  | SIGNATURE name = uident NEWLINE INDENT signature_items term_end
    { mk_module_signature $startpos $endpos name $5 }


signature_items:
  | { [] }
  | signature_item { [$1] }
  | signature_item sep signature_items { $1 :: $3 }

signature_item:
  | signature_item_desc
    {
      { id = fresh_id ();
        signature_item_desc = $1;
        loc = mk_loc $startpos $endpos; }}

signature_item_desc:
  | VAL name = ident COLON value_ty = ty
    {
      mk_signature_value $startpos $endpos name value_ty
    }
  | FOREIGN name = fn_operator_or_fn_name COLON value_ty = ty EQ symbol = symbol
    {
      let symbol_name, startpos, endpos = symbol in
      let ext_ident =
        mk_external_fn
          {name = symbol_name; loc = mk_loc startpos endpos } value_ty Foreign
      in
      mk_signature_external_value $startpos $endpos name value_ty ext_ident
    }
  | PRIMITIVE name = fn_operator_or_fn_name COLON value_ty = ty EQ symbol = symbol
    {
      let symbol_name, startpos, endpos = symbol in
      match Primitives.find_primitive symbol_name with
      | None -> failwith
          (Printf.sprintf "Primitive %s is unknown." symbol_name)
      | Some prim ->
        if not (Primitives.ty_match_primitive_instance value_ty prim) then
          failwith
            (Printf.sprintf
               "Primitive %s does not have type %s,"
               symbol_name
               (Pretty_print_code.string_of_ty value_ty));

      let ext_ident =
        mk_external_fn
          {name = symbol_name; loc = mk_loc startpos endpos } value_ty Primitive
      in
      mk_signature_external_value $startpos $endpos name value_ty ext_ident
    }

structure_items:
  | { [] }
  | structure_item sep structure_items { $1 :: $3 }
  | structure_item structure_items     { $1 :: $2 }

structure_item:
  | structure_item_desc { mk_structure_item $startpos $endpos $1 }

structure_item_desc:
  | let_def { Str_Let $1 }
  | module_structure { Str_ModuleStructure $1 }
  | module_signature { Str_ModuleSignature $1 }
  | type_def { Str_Type $1 }
  | FOREIGN name = fn_operator_or_fn_name COLON value_ty = ty EQ symbol = symbol
    {
      let symbol_name, startpos, endpos = symbol in
      let ext_ident =
        mk_external_fn
          {name = symbol_name; loc = mk_loc startpos endpos } value_ty Foreign
      in
      mk_structure_external_value $startpos $endpos name value_ty ext_ident
    }
  | PRIMITIVE name = fn_operator_or_fn_name COLON value_ty = ty EQ symbol = symbol
    {
      let symbol_name, startpos, endpos = symbol in
      match Primitives.find_primitive symbol_name with
      | None -> failwith
          (Printf.sprintf "Primitive %s is unknown." symbol_name)
      | Some prim ->
        if not (Primitives.ty_match_primitive_instance value_ty prim) then
          failwith
            (Printf.sprintf
               "Primitive '%s' does not have instance of type '%s',"
               symbol_name
               (Pretty_print_code.string_of_ty value_ty));

      let ext_ident =
        mk_external_fn
          {name = symbol_name; loc = mk_loc startpos endpos } value_ty Primitive
      in
      mk_structure_external_value $startpos $endpos name value_ty ext_ident
    }

%inline symbol:
  | STRING { ($1, $startpos, $endpos) }

let_def:
  | LET REC name = fn_operator_or_fn_name params = params eq_body = eq_let_body_expr
    {
      if params = [] then
        let (value, ty_opt) = eq_body in
        let pat = mk_pattern $startpos $endpos (Pat_Ident name) in
        mk_letdef $startpos $endpos LetVal pat NonRecursive value ty_opt
      else
        let (value, ty_opt) = eq_body in
        let lambda = mk_lambda $startpos $endpos params value ty_opt in
        let pat = mk_pattern $startpos $endpos (Pat_Ident name) in
        let value_expr = mk_expr $startpos $endpos (Exp_Lambda lambda) in
        mk_letdef $startpos $endpos LetFun pat Recursive value_expr None
    }
  | LET name = fn_operator_or_fn_name params = params eq_body = eq_let_body_expr
    {
      if params = [] then
        let (value, ty_opt) = eq_body in
        let pat = mk_pattern $startpos $endpos (Pat_Ident name) in
        mk_letdef $startpos $endpos LetVal pat NonRecursive value ty_opt
      else
        let (value, ty_opt) = eq_body in
        let lambda = mk_lambda $startpos $endpos params value ty_opt in
        let pat = mk_pattern $startpos $endpos (Pat_Ident name) in
        let value_expr = mk_expr $startpos $endpos (Exp_Lambda lambda) in
        mk_letdef $startpos $endpos LetFun pat NonRecursive value_expr None
    }

%inline eq_let_body_expr:
  | EQ body_sequence { ($2, None) }
  | COLON ty = ty EQ body_sequence = body_sequence
    { (body_sequence, Some ty) }

%inline lambda:
  | FUN params_lambda lambda_body
    { mk_lambda $startpos $endpos $2 (fst $3) (snd $3) }

params_lambda:
  | param_lambda                  { [$1] }
  | param_lambda params_lambda    { $1 :: $2 }

param_lambda:
  | pattern { mk_param $startpos $endpos $1 None }
  | LPAREN pattern COLON ty RPAREN { mk_param $startpos $endpos $2 (Some $4) }

%inline lambda_body:
  | ARROW expr          { ($2, None) }
  | COLON ty ARROW expr { ($4, Some $2) }

%inline sep:
  | NEWLINE { () }

sequence:
  | sequence_expr   { $1 }
  | expr            { $1 }

%inline sequence_expr:
  | NEWLINE INDENT sequence_exprs term_end { mk_seq $startpos $endpos $3 }

sequence_exprs:
  | expr                        { [$1] }
  | expr sep                    { [$1] }
  | expr sep sequence_exprs     { $1 :: $3 }
  | let_def                     { [mk_expr $startpos $endpos (Exp_Let $1)] }
  | let_def sep                 { [mk_expr $startpos $endpos (Exp_Let $1)] }
  | let_def sep sequence_exprs  { mk_expr $startpos $endpos (Exp_Let $1) :: $3 }
  | let_def sequence_exprs      { (mk_expr $startpos $endpos (Exp_Let $1)) :: $2 }

body_sequence:
  | expr          { $1 }
  | sequence_expr { $1 }

elseif_chain:
  | { None }
  | ELSEIF expr = expr THEN cond_seq = body_sequence else_chain = elseif_chain
    { Some
        (mk_expr $startpos $endpos
            (Exp_If
              {
                condition = expr;
                then_branch = cond_seq;
                else_branch = else_chain}))
    }
  | ELSE body_sequence { Some $2 }

loop_body:
  | expr            { $1 }
  | sequence_expr   { $1 }

ty:
  | name = ident
    { mk_ty $startpos $endpos (Ty_Defined { name; args = [] }) }

  | TY_INT64  { mk_ty $startpos $endpos (Ty_Constant Ty_Int64) }
  | TY_INT32  { mk_ty $startpos $endpos (Ty_Constant Ty_Int32) }
  | TY_INT16  { mk_ty $startpos $endpos (Ty_Constant Ty_Int16) }
  | TY_INT8   { mk_ty $startpos $endpos (Ty_Constant Ty_Int8)  }

  | TY_UINT64 { mk_ty $startpos $endpos (Ty_Constant Ty_UInt64) }
  | TY_UINT32 { mk_ty $startpos $endpos (Ty_Constant Ty_UInt32) }
  | TY_UINT16 { mk_ty $startpos $endpos (Ty_Constant Ty_UInt16) }
  | TY_UINT8  { mk_ty $startpos $endpos (Ty_Constant Ty_UInt8) }

  | TY_F32    { mk_ty $startpos $endpos (Ty_Constant Ty_F32) }
  | TY_F64    { mk_ty $startpos $endpos (Ty_Constant Ty_F64) }

  | TY_CHAR   { mk_ty $startpos $endpos (Ty_Constant Ty_Char) }
  | TY_BOOL   { mk_ty $startpos $endpos (Ty_Constant Ty_Bool) }
  | TY_UNIT   { mk_ty $startpos $endpos (Ty_Constant Ty_Unit) }
  | TY_STRING { mk_ty $startpos $endpos (Ty_Constant Ty_String) }

  | ty TY_ARRAY { mk_ty $startpos $endpos (Ty_Array $1) }
  | LPAREN ty_tuple RPAREN { mk_ty $startpos $endpos (Ty_Tuple $2) }
  | lhs = ty ARROW rhs = ty
    { mk_ty $startpos $endpos (Ty_Arrow (lhs, rhs)) }

  | LPAREN ty RPAREN { $2 }

ty_tuple:
  | ty COMMA ty       { [$1; $3] }
  | ty COMMA ty_tuple { $1 :: $3 }


record_field_ty:
  | field_name = ident COLON ty
    { mk_record_field_decl $startpos $endpos field_name $3 Immutable }
  | MUTABLE field_name = ident COLON ty
    { mk_record_field_decl $startpos $endpos field_name $4 Mutable }


record_field_ty_list:
  | field_desc = record_field_ty { [field_desc] }
  | field_desc = record_field_ty SEMI record_field_ty_list = record_field_ty_list
    { field_desc :: record_field_ty_list }

ty_constructor_decls:
  | ty_constructor_decl                           { [$1] }
  | ty_constructor_decl BAR ty_constructor_decls { $1 :: $3 }

%inline ty_constructor_decl:
  | name = uident       { mk_constructor_decl $startpos $endpos name None }
  | name = uident OF ty { mk_constructor_decl $startpos $endpos name (Some ( Constr_ty $3))}
  | name = uident OF LBRACE record_ty = record_field_ty_list RBRACE
    { mk_constructor_decl $startpos $endpos name
        (Some (Constr_record record_ty)) }

%inline type_def:
  | TYPE name = ident EQ constructors = ty_constructor_decls
    { mk_ty_decl $startpos $endpos name []
        (Tydef_Variant constructors)
        [] }
  | TYPE name = ident EQ  LBRACE record_ty = record_field_ty_list RBRACE
    { mk_ty_decl $startpos $endpos name []
        (Tydef_Record record_ty)
        [] }

param:
  | pattern
    { mk_param $startpos $endpos $1 None }
  | LPAREN pattern COLON ty RPAREN
    { mk_param $startpos $endpos $2 (Some $4) }

params:
  |               { [] }
  | param params  { $1 :: $2 }

args:
  | atom_expr       { [$1] }
  | atom_expr args  { $1 :: $2 }

%inline ident:
  | IDENT
    { let is_operator = check_operator $1 in
      mk_ident ~is_operator $startpos $endpos $1 }

%inline fn_operator_or_fn_name:
  | LPAREN operator RPAREN { mk_ident ~is_operator:true $startpos $endpos $2 }
  | IDENT
    { if check_operator $1 then
        failwith "defining operator should be in ( ) like (==)"
      else mk_ident $startpos $endpos $1 }

%inline uident:
  | UIDENT { mk_ident $startpos $endpos $1 }

%inline pattern_desc_simple:
  | INT                                 { Pat_IntLit $1 }
  | STRING                              { Pat_StringLit $1 }
  | CHAR                                { Pat_CharLit $1 }
  | FLOAT                               { Pat_FloatLit $1 }
  | BOOL_VAL                            { Pat_BoolLit $1 }
  | LPAREN RPAREN                       { Pat_Unit }
  | LPAREN pattern_tuple RPAREN         { Pat_Tuple { elements = $2} }
  | LBRACE record_pattern_list RBRACE   { Pat_Record { fields = $2} }
  | name = ident                        { if name.name = "_" then Pat_Any else Pat_Ident name }

%inline pattern_simple:
  | pattern_desc_simple {mk_pattern $startpos $endpos $1}

%inline pattern_single_constructor:
  | name = uident
      {mk_pattern $startpos $endpos (Pat_Constructor {name ; value = None})}

%inline pattern_uident:
  | name = uident pattern_simple
    {  mk_pattern $startpos $endpos (Pat_Constructor { name; value = Some $2}) }
  | name = uident LPAREN pattern RPAREN
    {  mk_pattern $startpos $endpos (Pat_Constructor { name; value = Some $3}) }
  | name = uident pattern_single_constructor
    {  mk_pattern $startpos $endpos (Pat_Constructor { name; value = Some $2 }) }
  | name = uident LPAREN pattern_single_constructor RPAREN
    {  mk_pattern $startpos $endpos (Pat_Constructor { name; value = Some $3 }) }
  | name = uident
    { mk_pattern $startpos $endpos (Pat_Constructor { name; value = None}) }

pattern:
  | pattern_uident                 { $1 }
  | LPAREN pattern_uident RPAREN   { $2 }
  | pattern_simple                 { $1 }
  | LPAREN pattern_simple RPAREN   { $2 }

pattern_tuple:
  | pattern COMMA pattern            { [$1; $3] }
  | pattern COMMA pattern_tuple      { $1 :: $3 }

record_pattern_list:
  | field_pattern_desc                          { [$1] }
  | field_pattern_desc SEMI record_pattern_list { $1 :: $3 }

%inline field_pattern_desc:
  | field_name = ident
    {
      { id = fresh_id (); name = field_name; value = None;
        loc = mk_loc $startpos $endpos }
    }
  | field_name = ident EQ pattern
    {
      { id = fresh_id (); name = field_name; value = Some $3;
        loc = mk_loc $startpos $endpos }
    }

%inline ident_atomic:
  | id = ident { mk_expr $startpos $endpos (Exp_Ident id) }

%inline uident_atomic:
  | id = uident
    { mk_expr $startpos $endpos
        (Exp_VariantConstructor { name = id; arg = None })
    }

pattern_case:
  | pattern ARROW body_sequence
    { mk_pattern_case $startpos $endpos $1 $3 None }
  | pattern WHEN guard = expr ARROW body_sequence
    { mk_pattern_case $startpos $endpos $1 $5 (Some guard) }

match_pattern:
  |                                         { [] }
  | pattern_case match_pattern              { $1 :: $2 }
  | BAR pattern_case match_pattern          { $2 :: $3 }
  | BAR pattern_case NEWLINE match_pattern  { $2 :: $4 }
  | pattern_case BAR match_pattern          { $1 :: $3 }

atom_expr:
  | ident_atomic  { $1 }
  | uident_atomic { $1 }
  | LPAREN RPAREN
    { mk_constant $startpos $endpos Const_Unit
      |> fun c -> mk_expr $startpos $endpos (Exp_Constant c)}
  | BOOL_VAL
    { mk_constant $startpos $endpos (Const_BoolLit $1)
      |> fun c -> mk_expr $startpos $endpos (Exp_Constant c)}
  | INT
    { mk_constant $startpos $endpos (Const_IntLit $1)
      |> fun c -> mk_expr $startpos $endpos (Exp_Constant c)}
  | STRING
    { mk_constant $startpos $endpos (Const_StringLit $1)
      |> fun c -> mk_expr $startpos $endpos (Exp_Constant c)}
  | CHAR
    { mk_constant $startpos $endpos (Const_CharLit $1)
      |> fun c -> mk_expr $startpos $endpos (Exp_Constant c)}
  | FLOAT
    { mk_constant $startpos $endpos (Const_FloatLit $1)
      |> fun c -> mk_expr $startpos $endpos (Exp_Constant c)}
  | LPAREN expr RPAREN { $2 }
  | LPAREN tuple_expr RPAREN
    { mk_expr $startpos $endpos (Exp_Tuple { elements = $2 })}
  | LBRACE record_fields_expr RBRACE
    { mk_expr $startpos $endpos (Exp_Record { fields = $2})}
  | lambda  { mk_expr $startpos $endpos (Exp_Lambda $1) }

simple_expr:
  | operation  { $1 }
  | expr_variant  { $1 }
  | expr LBRACKET_BAR expr RBRACKET_BAR
    { let closure = mk_ident ~is_operator:true $startpos $endpos "uindex" in
      mk_expr $startpos $endpos
        (Exp_Apply
           { closure_fun = mk_expr $startpos $endpos (Exp_Ident closure);
             args = [$1; $3] }) }
  | expr LBRACKET_BAR expr RBRACKET_BAR COLONEQ expr
    { let closure =
        mk_ident ~is_operator:true $startpos $endpos "uindex_get" in
      mk_expr $startpos $endpos
        (Exp_Apply
           { closure_fun = mk_expr $startpos $endpos (Exp_Ident closure);
             args = [$1; $3; $6] }) }
  | expr DOT IDENT
    { let ident = mk_ident $startpos $endpos $3 in
      mk_expr $startpos $endpos
        (Exp_Field { record = $1; field_name = ident }) }
  | expr DOT IDENT COLONEQ expr
    { let ident = mk_ident $startpos $endpos $3 in
      mk_expr $startpos $endpos
        (Exp_FieldSet { record = $1; field_name = ident; value = $5 }) }

apply_expr:
  | fn = fn_operator_or_fn_name apply_args
    { let closure_fun = mk_expr $startpos $endpos (Exp_Ident fn) in
      mk_expr $startpos $endpos (Exp_Apply { closure_fun; args = $2 }) }
  | expr apply_args
    { mk_expr $startpos $endpos (Exp_Apply { closure_fun = $1; args = $2 }) }

apply_args:
  | atom_expr             { [$1] }
  | atom_expr apply_args  { $1::$2 }

tuple_expr:
  | expr COMMA expr            { [$1; $3] }
  | expr COMMA tuple_expr      { $1::$3 }

expr_variant:
  | name = uident expr
    { mk_expr $startpos $endpos
        (Exp_VariantConstructor { name; arg = Some $2 })
    }

%inline operation:
  | expr op = operator expr
    { let closure = mk_expr $startpos $endpos
        (Exp_Ident (mk_ident ~is_operator:true $startpos $endpos op)) in
      mk_expr $startpos $endpos
        (Exp_Apply { closure_fun = closure; args = [$1; $3] }) }
  | MINUS expr
    { let closure = mk_expr $startpos $endpos
        (Exp_Ident
           (mk_ident ~is_operator:true $startpos $endpos "unegative")) in
      mk_expr $startpos $endpos (Exp_Apply { closure_fun = closure; args = [$2] }) }
  | PLUS expr
    { let closure = mk_expr $startpos $endpos
        (Exp_Ident
           (mk_ident ~is_operator:true $startpos $endpos "upositive")) in
      mk_expr $startpos $endpos (Exp_Apply { closure_fun = closure; args = [$2] }) }
  | BANG expr
    { let closure = mk_expr $startpos $endpos
        (Exp_Ident (mk_ident ~is_operator:true $startpos $endpos "!")) in
      mk_expr $startpos $endpos (Exp_Apply { closure_fun = closure; args = [$2] }) }
  | NOT expr
    { let ident = mk_ident $startpos $endpos "not" in
      let closure = mk_expr $startpos $endpos (Exp_Ident ident) in
      mk_expr $startpos $endpos (Exp_Apply { closure_fun = closure; args = [$2] }) }

%inline operator:
  (* = := ! *)
  | EQ        { "=" }
  | COLONEQ   { ":=" }
  | BANG      { "!" }

  (* && || *)
  | AMPAMPAND { "&&" }
  | BARBAR    { "||" }

  (* > < >= <= == != *)
  | GT        { ">" }
  | LT        { "<" }
  | GTEQ      { ">=" }
  | LTEQ      { "<=" }
  | EQEQ      { "==" }
  | BANGEQ    { "!=" }

  (* + - *)
  | PLUS      { "+" }
  | MINUS     { "-" }

  (* * % / *)
  | TIMES     { "*" }
  | PERCENT   { "%" }
  | SLASH     { "/" }

  | CARET     { "^" }

expr:
  | atom_expr    { $1 }
  | simple_expr  { $1 }
  | apply_expr   { $1 }
  | let_def      { mk_expr $startpos $endpos (Exp_Let $1)}
  | IF expr THEN body_sequence elseif_chain
    { mk_expr $startpos $endpos
        (Exp_If { condition = $2; then_branch = $4; else_branch = $5})}
  | WHILE expr DO loop_body
    { mk_expr $startpos $endpos (Exp_While { condition = $2; body = $4})}
  | LOOP sequence
    { mk_expr $startpos $endpos (Exp_Loop { condition = $2})}
  | BREAK expr
    { mk_expr $startpos $endpos (Exp_Break { value = Some $2 })}
  | CONTINUE
    { mk_expr $startpos $endpos (Exp_Continue)}
  | RETURN expr
    { mk_expr $startpos $endpos (Exp_Return { value = Some $2})}
  | MATCH expr = expr WITH NEWLINE mpat = match_pattern
    { mk_expr $startpos $endpos (Exp_Match { expr; cases = mpat})}
  | MATCH expr = expr WITH mpat = match_pattern
    { mk_expr $startpos $endpos (Exp_Match { expr; cases = mpat})}

record_fields_expr:
  | { [] }
  | field_name = ident EQ expr
    { let field_name = (field_name : ident) in
      [mk_record_field_expr $startpos $endpos field_name $3]}
  | field_name = ident EQ expr SEMI record_fields_expr
    { let field_name = (field_name : ident) in
      mk_record_field_expr $startpos $endpos field_name $3 :: $5}

%%
