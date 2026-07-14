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
%token TY_INT TY_FLOAT TY_DOUBLE TY_CHAR TY_BOOL TY_UNIT TY_STRING TY_ARRAY TY_LIST TY_TUPLE
%token REC FN LET RETURN IF ELSE ELSEIF THEN
%token VAL EXTERN SIGNATURE
%token WHILE LOOP DO END LOCAL CONTINUE BREAK LAMBDA MATCH WITH TYPE OF MUT
%token LPAREN RPAREN LBRACKET RBRACKET LBRACE RBRACE LBRACKET_BAR RBRACKET_BAR
%token COMMA SEMI COLON NEWLINE DOT ARROW
%token EQ PLUS_EQ MINUS_EQ PLUS MINUS TIMES DIV MOD
%token LT GT EQEQ NEQ LEQ GEQ AND
%token OR NOT BITAND BITOR BITXOR LSHIFT RSHIFT BITNOT BANG UNDERSCORE
%token INDENT DEDENT EOF PIPE
%token MODULE
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

%nonassoc LT GT LEQ GEQ EQEQ NEQ
%left OR
%left AND
%left BITOR
%left BITXOR
%left BITAND
%left LSHIFT RSHIFT
%left PLUS MINUS
%left TIMES DIV MOD
%right ARROW

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
  | MODULE name = uident structure_items term_end
    { mk_module_struct $startpos $endpos name $3 }

module_signature:
  | MODULE name = uident signature_items term_end
    { mk_module_signature $startpos $endpos name $3 }


signature_items:
  | { [] }
  | signature { [$1] }
  | signature sep signature_items { $1 :: $3 }

signature:
  | VAL name = ident COLON value_ty = ty
      {
        mk_signature_item $startpos $endpos name value_ty
      }
  | EXTERN name = ident COLON value_ty = ty EQ ext_name = STRING
      {
        mk_signature_external_value $startpos $endpos name value_ty ext_name
      }

structure_items:
  | { [] }
  | structure { [$1] }
  | structure sep structure_items { $1 :: $3 }
  | structure structure_items     { $1 :: $2 }

structure:
  | structure_desc { mk_structure_item $startpos $endpos $1 }

structure_desc:
  | FN REC name = ident params = params f_body = fun_body_def
      {
        let (body, ret_ty_opt) = f_body in
        let lambda = mk_lambda $startpos $endpos params body ret_ty_opt in
        let value_expr = mk_expr $startpos $endpos (Exp_Lambda lambda) in
        Str_Fun { rec_flag = Recursive; name; body = value_expr; ty_opt = None }
      }
  | FN name = ident params = params f_body = fun_body_def
      {
        let (body, ret_ty_opt) = f_body in
        let lambda = mk_lambda $startpos $endpos params body ret_ty_opt in
        let value_expr = mk_expr $startpos $endpos (Exp_Lambda lambda) in
        Str_Fun { rec_flag = NonRecursive; name; body = value_expr; ty_opt = None }
      }
  | let_def { Str_Let $1 }
  | module_structure { Str_ModuleStruct $1 }
  | type_def { Str_TypeDef $1 }
  | SIGNATURE COLON NEWLINE INDENT signatures = signature_items term_end
    {
      Str_Signature signatures
    }

fun_body_def:
  | EQ cond_sequence { ($2, None) }
  | COLON ty EQ cond_sequence { ($4, Some $2) }

let_def:
  | LET pat = pattern eq_body = eq_let_body_expr
      {
        let (value, ty_opt) = eq_body in
        mk_letdef $startpos $endpos LetVal pat NonRecursive value ty_opt
      }
  | LET REC name = ident params = params eq_body = eq_let_body_expr
      {
        let (value, ty_opt) = eq_body in
        let lambda = mk_lambda $startpos $endpos params value ty_opt in
        let pat = mk_pattern $startpos $endpos (Pat_Ident name) in
        let value_expr = mk_expr $startpos $endpos (Exp_Lambda lambda) in
        mk_letdef $startpos $endpos LetFun pat Recursive value_expr None
      }
  | LET name = ident params = params eq_body = eq_let_body_expr
      {
        let (value, ty_opt) = eq_body in
        let lambda = mk_lambda $startpos $endpos params value ty_opt in
        let pat = mk_pattern $startpos $endpos (Pat_Ident name) in
        let value_expr = mk_expr $startpos $endpos (Exp_Lambda lambda) in
        mk_letdef $startpos $endpos LetFun pat NonRecursive value_expr None
      }

eq_let_body_expr:
  | EQ cond_sequence { ($2, None) }
  | COLON ty = ty EQ cond_sequence = cond_sequence { (cond_sequence, Some ty) }

lambda:
  | LAMBDA params lambda_body
      { mk_lambda $startpos $endpos $2 (fst $3) (snd $3) }

lambda_body:
  | ARROW sequence { ($2, None) }
  | COLON ty ARROW sequence { ($4, Some $2) }

sep:
  | NEWLINE { () }

sequence:
  | sequence_expr   { $1 }
  | expr            { $1 }

sequence_expr:
  | NEWLINE INDENT sequence_exprs term_end
      { mk_seq $startpos $endpos $3 }

sequence_exprs:
  | expr { [$1] }
  | expr sep { [$1] }
  | expr sep sequence_exprs { $1 :: $3 }
  | expr sequence_exprs { $1 :: $2 }

cond_sequence:
  | expr { $1 }
  | sequence_expr { $1 }

elseif_chain:
  | { None }
  | ELSEIF expr = expr THEN cond_seq = cond_sequence else_chain = elseif_chain
      {
        Some
          (mk_expr $startpos $endpos
             (Exp_If { cond = expr; then_branch = cond_seq; else_branch = else_chain }))
      }
  | ELSE cond_sequence
      { Some $2 }

loop_body:
  | expr            { $1 }
  | sequence_expr   { $1 }

opt_expr:
  | { None }
  | expr { Some $1 }

ty:
  | name = uident
      { mk_ty $startpos $endpos (Ty_Defined { name; args = [] }) }
  | TY_INT
      { mk_ty $startpos $endpos
          (Ty_Defined
             {
               name = mk_ident $startpos $endpos "int";
               args = [];
             }) }

  | TY_INT64 { mk_ty $startpos $endpos (Ty_Constant Ty_Int64) }
  | TY_INT32 { mk_ty $startpos $endpos (Ty_Constant Ty_Int32) }
  | TY_INT16 { mk_ty $startpos $endpos (Ty_Constant Ty_Int16) }
  | TY_INT8 { mk_ty $startpos $endpos (Ty_Constant Ty_Int8) }

  | TY_UINT64 { mk_ty $startpos $endpos (Ty_Constant Ty_UInt64) }
  | TY_UINT32 { mk_ty $startpos $endpos (Ty_Constant Ty_UInt32) }
  | TY_UINT16 { mk_ty $startpos $endpos (Ty_Constant Ty_UInt16) }
  | TY_UINT8 { mk_ty $startpos $endpos (Ty_Constant Ty_UInt8) }

  | TY_FLOAT { mk_ty $startpos $endpos (Ty_Constant Ty_Float) }
  | TY_DOUBLE { mk_ty $startpos $endpos (Ty_Constant Ty_Double) }

  | TY_CHAR
      {
        mk_ty $startpos $endpos
          (Ty_Defined
             {
               name = mk_ident $startpos $endpos "char";
               args = [];
             })
      }
  | TY_BOOL
      {
        mk_ty $startpos $endpos
          (Ty_Defined
             {
               name = mk_ident $startpos $endpos "bool";
               args = [];
             })
      }
  | TY_UNIT
      { mk_ty $startpos $endpos (Ty_Constant Ty_Unit) }
  | TY_STRING
      {
        mk_ty $startpos $endpos
          (Ty_Defined
             {
               name = mk_ident $startpos $endpos "string";
               args = [];
             })
      }
  | TY_TUPLE LPAREN ty_tuple RPAREN
      { mk_ty $startpos $endpos (Ty_Tuple $3) }
  | TY_LIST LBRACKET ty RBRACKET
      {
        mk_ty $startpos $endpos
          (Ty_Defined
             {
               name = mk_ident $startpos $endpos "list";
               args = [ $3 ];
             })
      }
  | TY_ARRAY LBRACKET_BAR ty RBRACKET_BAR
      {
        mk_ty $startpos $endpos
          (Ty_Defined
             {
               name = mk_ident $startpos $endpos "array";
               args = [ $3 ];
             })
      }
  | LPAREN ty_arrow RPAREN ARROW ty
      { mk_ty $startpos $endpos (Ty_Arrow ($2, $5)) }
  | LPAREN ty RPAREN
      { $2 }
    | lhs = ty ARROW rhs = ty
      { mk_ty $startpos $endpos (Ty_Arrow ([ lhs ], rhs)) }

record_field_ty:
  | field_name = ident COLON ty
    { mk_record_field_decl $startpos $endpos field_name $3 Immutable }
  | MUT field_name = ident COLON ty
    { mk_record_field_decl $startpos $endpos field_name $4 Mutable }


record_field_ty_list:
  | field_desc = record_field_ty
    { [field_desc] }
  | field_desc = record_field_ty SEMI record_field_ty_list = record_field_ty_list
    { field_desc :: record_field_ty_list }

ty_tuple:
  | ty { [$1] }
  | ty COMMA ty_tuple { $1 :: $3 }

ty_arrow:
  | ty { [$1] }
  | ty ARROW ty_arrow { $1 :: $3 }

ty_constructor_decls:
  | ty_constructor_decl                           { [$1] }
  | ty_constructor_decl PIPE ty_constructor_decls { $1 :: $3 }

ty_constructor_decl:
  | name = uident          { mk_constructor_decl $startpos $endpos name None }
  | name = uident OF ty    { mk_constructor_decl $startpos $endpos name (Some $3) }

type_def:
  | TYPE name = ident EQ constructors = ty_constructor_decls
      {
        mk_ty_decl $startpos $endpos name []
          (Tydef_Variant constructors)
          []
      }
  | TYPE name = ident EQ  LBRACE record_ty = record_field_ty_list RBRACE
      {
        mk_ty_decl $startpos $endpos name []
          (Tydef_Record record_ty)
          []
      }

param:
  | pattern
      { mk_param $startpos $endpos $1 Immutable None }
  | MUT pattern
      { mk_param $startpos $endpos $2 Mutable None }
  | LPAREN pattern COLON ty RPAREN
      { mk_param $startpos $endpos $2 Immutable (Some $4) }
  | LPAREN MUT pattern COLON ty RPAREN
      { mk_param $startpos $endpos $3 Mutable (Some $5) }

params:
  | param           { [$1] }
  | param params    { $1 :: $2 }

args:
  | atom_expr        { [$1] }
  | atom_expr args   { $1 :: $2 }

ident:
  | IDENT { mk_ident $startpos $endpos $1 }

uident:
  | UIDENT { mk_ident $startpos $endpos $1 }

pattern_desc:
  | UNDERSCORE                          { Pat_Wildcard }
  | INT                                 { Pat_IntLit $1 }
  | STRING                              { Pat_StringLit $1 }
  | CHAR                                { Pat_CharLit $1 }
  | FLOAT                               { Pat_FloatLit $1 }
  | BOOL_VAL                            { Pat_BoolLit $1 }
  | name = ident                        { Pat_Ident name }
  | LPAREN RPAREN                       { Pat_Unit }
  | LPAREN pattern_list RPAREN          { Pat_Tuple $2 }
  | LBRACE record_pattern_list RBRACE   { Pat_Record $2 }
    | name = uident LPAREN pattern_desc RPAREN
      { Pat_Constructor (name, Some (mk_pattern $startpos $endpos $3)) }
    | name = uident                       { Pat_Constructor (name, None) }

pattern:
  | pattern_desc { mk_pattern $startpos $endpos $1 }

pattern_list:
  | pattern                     { [$1] }
  | pattern COMMA pattern_list  { $1 :: $3 }

record_pattern_list:
  | field_pattern_desc                          { [$1] }
  | field_pattern_desc SEMI record_pattern_list { $1 :: $3 }

field_pattern_desc:
  | field_name = ident { (field_name, None) }
  | field_name = ident EQ pattern { (field_name, Some $3) }

ident_atomic:
  | id = ident
      { mk_expr $startpos $endpos (Exp_Ident id) }

uident_atomic:
  | id = uident
      {
        mk_expr $startpos $endpos
          (Exp_VariantConstructor { name = id; arg = None })
      }

pattern_case:
  | pattern ARROW cond_sequence
      { mk_pattern_case $startpos $endpos $1 $3 None }

match_pattern:
  | pattern_case                { [$1] }
  | pattern_case match_pattern  { $1 :: $2 }

atom_expr:
  | LPAREN RPAREN
      {
        mk_constant $startpos $endpos Const_Unit
        |> fun c -> mk_expr $startpos $endpos (Exp_Constant c)
      }
  | BOOL_VAL
      {
        mk_constant $startpos $endpos (Const_BoolLit $1)
        |> fun c -> mk_expr $startpos $endpos (Exp_Constant c)
      }
  | INT
      {
        mk_constant $startpos $endpos (Const_IntLit $1)
        |> fun c -> mk_expr $startpos $endpos (Exp_Constant c)
      }
  | STRING
      {
        mk_constant $startpos $endpos (Const_StringLit $1)
        |> fun c -> mk_expr $startpos $endpos (Exp_Constant c)
      }
  | CHAR
      {
        mk_constant $startpos $endpos (Const_CharLit $1)
        |> fun c -> mk_expr $startpos $endpos (Exp_Constant c)
      }
  | FLOAT
      {
        mk_constant $startpos $endpos (Const_FloatLit $1)
        |> fun c -> mk_expr $startpos $endpos (Exp_Constant c)
      }
  | ident_atomic { $1 }
  | uident_atomic { $1 }
  | LPAREN expr RPAREN { $2 }
  | LPAREN expr COMMA exprs RPAREN
      { mk_expr $startpos $endpos (Exp_Tuple ($2 :: $4)) }
  | LBRACKET COLON RBRACKET
      { mk_expr $startpos $endpos (Exp_Collection (Col_Array [])) }
  | LBRACKET expr COLON RBRACKET
      { mk_expr $startpos $endpos (Exp_Collection (Col_Array [$2])) }
  | LBRACKET expr COLON exprs RBRACKET
      { mk_expr $startpos $endpos (Exp_Collection (Col_Array ($2 :: $4))) }
  | LBRACKET COMMA RBRACKET
      { mk_expr $startpos $endpos (Exp_Collection (Col_List [])) }
  | LBRACKET expr COMMA RBRACKET
      { mk_expr $startpos $endpos (Exp_Collection (Col_List [$2])) }
  | LBRACKET expr COMMA exprs RBRACKET
      { mk_expr $startpos $endpos (Exp_Collection (Col_List ($2 :: $4))) }
  | lambda
      { mk_expr $startpos $endpos (Exp_Lambda $1) }
  | LBRACE record_fields_expr RBRACE
      { mk_expr $startpos $endpos (Exp_Record $2) }
  | LOCAL sequence { $2 }

postfix_expr:
  | atom_expr { $1 }
  | postfix_expr args
      { mk_expr $startpos $endpos (Exp_Apply { closure_fun = $1; args = $2 }) }
  | postfix_expr DOT field_name = ident
    { mk_expr $startpos $endpos (Exp_Field { record = $1; field_name }) }
  | postfix_expr LBRACKET expr RBRACKET
      { mk_expr $startpos $endpos (Exp_Index { collection = $1; index = $3 }) }

unary_expr:
  | postfix_expr { $1 }
  | MINUS unary_expr
      { mk_expr $startpos $endpos (Exp_UnOp (Unop_Arithmetic Neg, $2)) }
  | NOT unary_expr
      { mk_expr $startpos $endpos (Exp_UnOp (Unop_Logical Not, $2)) }
  | BANG unary_expr
      { mk_expr $startpos $endpos (Exp_UnOp (Unop_Logical Not, $2)) }
  | BITNOT unary_expr
      { mk_expr $startpos $endpos (Exp_UnOp (Unop_Bitwise BitNot, $2)) }

mul_expr:
  | unary_expr { $1 }
  | mul_expr TIMES unary_expr
      { mk_expr $startpos $endpos (Exp_BinOp (Binop_Arithmetic Mul, $1, $3)) }
  | mul_expr DIV unary_expr
      { mk_expr $startpos $endpos (Exp_BinOp (Binop_Arithmetic Div, $1, $3)) }
  | mul_expr MOD unary_expr
      { mk_expr $startpos $endpos (Exp_BinOp (Binop_Arithmetic Mod, $1, $3)) }

add_expr:
  | mul_expr { $1 }
  | add_expr PLUS mul_expr
      { mk_expr $startpos $endpos (Exp_BinOp (Binop_Arithmetic Add, $1, $3)) }
  | add_expr MINUS mul_expr
      { mk_expr $startpos $endpos (Exp_BinOp (Binop_Arithmetic Sub, $1, $3)) }

shift_expr:
  | add_expr { $1 }
  | shift_expr LSHIFT add_expr
      { mk_expr $startpos $endpos (Exp_BinOp (Binop_Bitwise LShift, $1, $3)) }
  | shift_expr RSHIFT add_expr
      { mk_expr $startpos $endpos (Exp_BinOp (Binop_Bitwise RShift, $1, $3)) }

bitand_expr:
  | shift_expr { $1 }
  | bitand_expr BITAND shift_expr
      { mk_expr $startpos $endpos (Exp_BinOp (Binop_Bitwise BitAnd, $1, $3)) }

bitxor_expr:
  | bitand_expr { $1 }
  | bitxor_expr BITXOR bitand_expr
      { mk_expr $startpos $endpos (Exp_BinOp (Binop_Bitwise BitXor, $1, $3)) }

bitor_expr:
  | bitxor_expr { $1 }
  | bitor_expr BITOR bitxor_expr
      { mk_expr $startpos $endpos (Exp_BinOp (Binop_Bitwise BitOr, $1, $3)) }

comp_expr:
  | bitor_expr { $1 }
  | comp_expr LT bitor_expr
      { mk_expr $startpos $endpos (Exp_BinOp (Binop_Comparison Lt, $1, $3)) }
  | comp_expr GT bitor_expr
      { mk_expr $startpos $endpos (Exp_BinOp (Binop_Comparison Gt, $1, $3)) }
  | comp_expr LEQ bitor_expr
      { mk_expr $startpos $endpos (Exp_BinOp (Binop_Comparison Le, $1, $3)) }
  | comp_expr GEQ bitor_expr
      { mk_expr $startpos $endpos (Exp_BinOp (Binop_Comparison Ge, $1, $3)) }
  | comp_expr EQEQ bitor_expr
      { mk_expr $startpos $endpos (Exp_BinOp (Binop_Comparison Eq, $1, $3)) }
  | comp_expr NEQ bitor_expr
      { mk_expr $startpos $endpos (Exp_BinOp (Binop_Comparison Ne, $1, $3)) }

and_expr:
  | comp_expr { $1 }
  | and_expr AND comp_expr
      { mk_expr $startpos $endpos (Exp_BinOp (Binop_Logical And, $1, $3)) }

or_expr:
  | and_expr { $1 }
  | or_expr OR and_expr
      { mk_expr $startpos $endpos (Exp_BinOp (Binop_Logical Or, $1, $3)) }

assign_expr:
  | or_expr { $1 }
  | postfix_expr EQ assign_expr
      { mk_expr $startpos $endpos (Exp_Assign { target = $1; value = $3; }) }
  | postfix_expr PLUS_EQ assign_expr
      {
        let value = mk_expr $startpos $endpos (Exp_BinOp (Binop_Arithmetic Add, $1, $3)) in
        mk_expr $startpos $endpos (Exp_Assign { target = $1; value; })
      }
  | postfix_expr MINUS_EQ assign_expr
      {
        let value = mk_expr $startpos $endpos (Exp_BinOp (Binop_Arithmetic Sub, $1, $3)) in
        mk_expr $startpos $endpos (Exp_Assign { target = $1; value; })
      }

expr:
  | let_def
      { mk_expr $startpos $endpos (Exp_Let $1) }
  | assign_expr { $1 }
  | IF expr THEN cond_sequence elseif_chain
      {
        mk_expr $startpos $endpos
          (Exp_If { cond = $2; then_branch = $4; else_branch = $5 })
      }
  | WHILE expr DO loop_body
      { mk_expr $startpos $endpos (Exp_While { cond = $2; body = $4 }) }
  | LOOP sequence
      { mk_expr $startpos $endpos (Exp_Loop $2) }
  | BREAK opt_expr
      { mk_expr $startpos $endpos (Exp_Break $2) }
  | CONTINUE
      { mk_expr $startpos $endpos (Exp_Continue) }
  | RETURN opt_expr
      { mk_expr $startpos $endpos (Exp_Return $2) }
  | MATCH expr = expr WITH mpat = match_pattern
      { mk_expr $startpos $endpos (Exp_Match (expr, mpat)) }

exprs:
  | expr                { [$1] }
  | expr COMMA exprs    { $1 :: $3 }

record_fields_expr:
  | { [] }
  | field_name = ident EQ expr
    {
      let field_name = (field_name : ident) in
      [mk_record_field_expr $startpos $endpos field_name.name $3]
    }
  | field_name = ident EQ expr SEMI record_fields_expr
    {
      let field_name = (field_name : ident) in
      mk_record_field_expr $startpos $endpos field_name.name $3 :: $5
    }

%%
