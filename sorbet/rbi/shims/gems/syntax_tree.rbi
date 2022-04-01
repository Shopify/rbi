# typed: strict

module SyntaxTree
  class Node
    sig { params(visitor: Visitor).void }
    def accept(visitor); end
  end

  class Parser
    sig { returns(SyntaxTree::Node) }
    def parse; end
  end

  class Visitor
    sig { params(node: T.nilable(Node)).void }
    def visit(node); end

    sig { params(nodes: T::Array[Node]).void }
    def visit_all(nodes); end

    sig { params(node: Node).void }
    def visit_child_nodes(node); end

    sig { params(node: ARef).void }
    def visit_aref(node); end

    sig { params(node: ARefField).void }
    def visit_aref_field(node); end

    sig { params(node: Alias).void }
    def visit_alias(node); end

    sig { params(node: ArgBlock).void }
    def visit_arg_block(node); end

    sig { params(node: ArgParen).void }
    def visit_arg_paren(node); end

    sig { params(node: ArgStar).void }
    def visit_arg_star(node); end

    sig { params(node: Args).void }
    def visit_args(node); end

    sig { params(node: ArgsForward).void }
    def visit_args_forward(node); end

    sig { params(node: ArrayLiteral).void }
    def visit_array(node); end

    sig { params(node: AryPtn).void }
    def visit_aryptn(node); end

    sig { params(node: Assign).void }
    def visit_assign(node); end

    sig { params(node: Assoc).void }
    def visit_assoc(node); end

    sig { params(node: AssocSplat).void }
    def visit_assoc_splat(node); end

    sig { params(node: BEGINBlock).void }
    def visit_BEGIN(node); end

    sig { params(node: Backref).void }
    def visit_backref(node); end

    sig { params(node: Backtick).void }
    def visit_backtick(node); end

    sig { params(node: BareAssocHash).void }
    def visit_bare_assoc_hash(node); end

    sig { params(node: Begin).void }
    def visit_begin(node); end

    sig { params(node: Binary).void }
    def visit_binary(node); end

    sig { params(node: BlockArg).void }
    def visit_block_arg(node); end

    sig { params(node: BlockVar).void }
    def visit_block_var(node); end

    sig { params(node: BodyStmt).void }
    def visit_bodystmt(node); end

    sig { params(node: BraceBlock).void }
    def visit_brace_block(node); end

    sig { params(node: Break).void }
    def visit_break(node); end

    sig { params(node: CHAR).void }
    def visit_CHAR(node); end

    sig { params(node: CVar).void }
    def visit_cvar(node); end

    sig { params(node: Call).void }
    def visit_call(node); end

    sig { params(node: Case).void }
    def visit_case(node); end

    sig { params(node: ClassDeclaration).void }
    def visit_class(node); end

    sig { params(node: Comma).void }
    def visit_comma(node); end

    sig { params(node: Command).void }
    def visit_command(node); end

    sig { params(node: CommandCall).void }
    def visit_command_call(node); end

    sig { params(node: Comment).void }
    def visit_comment(node); end

    sig { params(node: Const).void }
    def visit_const(node); end

    sig { params(node: ConstPathField).void }
    def visit_const_path_field(node); end

    sig { params(node: ConstPathRef).void }
    def visit_const_path_ref(node); end

    sig { params(node: ConstRef).void }
    def visit_const_ref(node); end

    sig { params(node: Def).void }
    def visit_def(node); end

    sig { params(node: DefEndless).void }
    def visit_def_endless(node); end

    sig { params(node: Defined).void }
    def visit_defined(node); end

    sig { params(node: Defs).void }
    def visit_defs(node); end

    sig { params(node: DoBlock).void }
    def visit_do_block(node); end

    sig { params(node: Dot2).void }
    def visit_dot2(node); end

    sig { params(node: Dot3).void }
    def visit_dot3(node); end

    sig { params(node: DynaSymbol).void }
    def visit_dyna_symbol(node); end

    sig { params(node: ENDBlock).void }
    def visit_END(node); end

    sig { params(node: Else).void }
    def visit_else(node); end

    sig { params(node: Elsif).void }
    def visit_elsif(node); end

    sig { params(node: EmbDoc).void }
    def visit_embdoc(node); end

    sig { params(node: EmbExprBeg).void }
    def visit_embexpr_beg(node); end

    sig { params(node: EmbExprEnd).void }
    def visit_embexpr_end(node); end

    sig { params(node: EmbVar).void }
    def visit_embvar(node); end

    sig { params(node: EndContent).void }
    def visit___end__(node); end

    sig { params(node: Ensure).void }
    def visit_ensure(node); end

    sig { params(node: ExcessedComma).void }
    def visit_excessed_comma(node); end

    sig { params(node: FCall).void }
    def visit_fcall(node); end

    sig { params(node: Field).void }
    def visit_field(node); end

    sig { params(node: Float).void }
    def visit_float(node); end

    sig { params(node: FndPtn).void }
    def visit_fndptn(node); end

    sig { params(node: For).void }
    def visit_for(node); end

    sig { params(node: GVar).void }
    def visit_gvar(node); end

    sig { params(node: HashLiteral).void }
    def visit_hash(node); end

    sig { params(node: Heredoc).void }
    def visit_heredoc(node); end

    sig { params(node: HeredocBeg).void }
    def visit_heredoc_beg(node); end

    sig { params(node: HshPtn).void }
    def visit_hshptn(node); end

    sig { params(node: IVar).void }
    def visit_ivar(node); end

    sig { params(node: Ident).void }
    def visit_ident(node); end

    sig { params(node: If).void }
    def visit_if(node); end

    sig { params(node: IfMod).void }
    def visit_if_mod(node); end

    sig { params(node: IfOp).void }
    def visit_if_op(node); end

    sig { params(node: Imaginary).void }
    def visit_imaginary(node); end

    sig { params(node: In).void }
    def visit_in(node); end

    sig { params(node: Int).void }
    def visit_int(node); end

    sig { params(node: Kw).void }
    def visit_kw(node); end

    sig { params(node: KwRestParam).void }
    def visit_kwrest_param(node); end

    sig { params(node: LBrace).void }
    def visit_lbrace(node); end

    sig { params(node: LBracket).void }
    def visit_lbracket(node); end

    sig { params(node: LParen).void }
    def visit_lparen(node); end

    sig { params(node: Label).void }
    def visit_label(node); end

    sig { params(node: LabelEnd).void }
    def visit_label_end(node); end

    sig { params(node: Lambda).void }
    def visit_lambda(node); end

    sig { params(node: MAssign).void }
    def visit_massign(node); end

    sig { params(node: MLHS).void }
    def visit_mlhs(node); end

    sig { params(node: MLHSParen).void }
    def visit_mlhs_paren(node); end

    sig { params(node: MRHS).void }
    def visit_mrhs(node); end

    sig { params(node: MethodAddBlock).void }
    def visit_method_add_block(node); end

    sig { params(node: ModuleDeclaration).void }
    def visit_module(node); end

    sig { params(node: Next).void }
    def visit_next(node); end

    sig { params(node: Not).void }
    def visit_not(node); end

    sig { params(node: Op).void }
    def visit_op(node); end

    sig { params(node: OpAssign).void }
    def visit_op_assign(node); end

    sig { params(node: Params).void }
    def visit_params(node); end

    sig { params(node: Paren).void }
    def visit_paren(node); end

    sig { params(node: Period).void }
    def visit_period(node); end

    sig { params(node: PinnedBegin).void }
    def visit_pinned_begin(node); end

    sig { params(node: PinnedVarRef).void }
    def visit_pinned_var_ref(node); end

    sig { params(node: Program).void }
    def visit_program(node); end

    sig { params(node: QSymbols).void }
    def visit_qsymbols(node); end

    sig { params(node: QSymbolsBeg).void }
    def visit_qsymbols_beg(node); end

    sig { params(node: QWords).void }
    def visit_qwords(node); end

    sig { params(node: QWordsBeg).void }
    def visit_qwords_beg(node); end

    sig { params(node: RAssign).void }
    def visit_rassign(node); end

    sig { params(node: RBrace).void }
    def visit_rbrace(node); end

    sig { params(node: RBracket).void }
    def visit_rbracket(node); end

    sig { params(node: RParen).void }
    def visit_rparen(node); end

    sig { params(node: RationalLiteral).void }
    def visit_rational(node); end

    sig { params(node: Redo).void }
    def visit_redo(node); end

    sig { params(node: RegexpBeg).void }
    def visit_regexp_beg(node); end

    sig { params(node: RegexpContent).void }
    def visit_regexp_content(node); end

    sig { params(node: RegexpEnd).void }
    def visit_regexp_end(node); end

    sig { params(node: RegexpLiteral).void }
    def visit_regexp_literal(node); end

    sig { params(node: Rescue).void }
    def visit_rescue(node); end

    sig { params(node: RescueEx).void }
    def visit_rescue_ex(node); end

    sig { params(node: RescueMod).void }
    def visit_rescue_mod(node); end

    sig { params(node: RestParam).void }
    def visit_rest_param(node); end

    sig { params(node: Retry).void }
    def visit_retry(node); end

    sig { params(node: Return).void }
    def visit_return(node); end

    sig { params(node: Return0).void }
    def visit_return0(node); end

    sig { params(node: SClass).void }
    def visit_sclass(node); end

    sig { params(node: Statements).void }
    def visit_statements(node); end

    sig { params(node: StringConcat).void }
    def visit_string_concat(node); end

    sig { params(node: StringContent).void }
    def visit_string_content(node); end

    sig { params(node: StringDVar).void }
    def visit_string_dvar(node); end

    sig { params(node: StringEmbExpr).void }
    def visit_string_embexpr(node); end

    sig { params(node: StringLiteral).void }
    def visit_string_literal(node); end

    sig { params(node: Super).void }
    def visit_super(node); end

    sig { params(node: SymBeg).void }
    def visit_sym_beg(node); end

    sig { params(node: SymbolContent).void }
    def visit_symbol_content(node); end

    sig { params(node: SymbolLiteral).void }
    def visit_symbol_literal(node); end

    sig { params(node: Symbols).void }
    def visit_symbols(node); end

    sig { params(node: SymbolsBeg).void }
    def visit_symbols_beg(node); end

    sig { params(node: TLamBeg).void }
    def visit_tlambeg(node); end

    sig { params(node: TLambda).void }
    def visit_tlambda(node); end

    sig { params(node: TStringBeg).void }
    def visit_tstring_beg(node); end

    sig { params(node: TStringContent).void }
    def visit_tstring_content(node); end

    sig { params(node: TStringEnd).void }
    def visit_tstring_end(node); end

    sig { params(node: TopConstField).void }
    def visit_top_const_field(node); end

    sig { params(node: TopConstRef).void }
    def visit_top_const_ref(node); end

    sig { params(node: Unary).void }
    def visit_unary(node); end

    sig { params(node: Undef).void }
    def visit_undef(node); end

    sig { params(node: Unless).void }
    def visit_unless(node); end

    sig { params(node: UnlessMod).void }
    def visit_unless_mod(node); end

    sig { params(node: Until).void }
    def visit_until(node); end

    sig { params(node: UntilMod).void }
    def visit_until_mod(node); end

    sig { params(node: VCall).void }
    def visit_vcall(node); end

    sig { params(node: VarAlias).void }
    def visit_var_alias(node); end

    sig { params(node: VarField).void }
    def visit_var_field(node); end

    sig { params(node: VarRef).void }
    def visit_var_ref(node); end

    sig { params(node: VoidStmt).void }
    def visit_void_stmt(node); end

    sig { params(node: When).void }
    def visit_when(node); end

    sig { params(node: While).void }
    def visit_while(node); end

    sig { params(node: WhileMod).void }
    def visit_while_mod(node); end

    sig { params(node: Word).void }
    def visit_word(node); end

    sig { params(node: Words).void }
    def visit_words(node); end

    sig { params(node: WordsBeg).void }
    def visit_words_beg(node); end

    sig { params(node: XString).void }
    def visit_xstring(node); end

    sig { params(node: XStringLiteral).void }
    def visit_xstring_literal(node); end

    sig { params(node: Yield).void }
    def visit_yield(node); end

    sig { params(node: Yield0).void }
    def visit_yield0(node); end

    sig { params(node: ZSuper).void }
    def visit_zsuper(node); end
  end
end