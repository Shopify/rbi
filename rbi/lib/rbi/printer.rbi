# typed: strict
# frozen_string_literal: true

# Printing

module RBI
  class PrinterError < Error; end

  class Printer < Visitor
    sig { returns(T::Boolean) }
    attr_accessor :print_locs, :in_visibility_group

    sig { returns(T.nilable(Node)) }
    attr_reader :previous_node

    sig { returns(Integer) }
    attr_reader :current_indent

    sig { returns(T.nilable(Integer)) }
    attr_reader :max_line_length

    sig { params(out: T.any(IO, StringIO), indent: Integer, print_locs: T::Boolean, max_line_length: T.nilable(Integer)).void }
    def initialize(out: $stdout, indent: 0, print_locs: false, max_line_length: nil); end

    sig { void }
    def indent; end

    sig { void }
    def dedent; end

    # Print a string without indentation nor `\n` at the end.
    sig { params(string: String).void }
    def print(string); end

    # Print a string without indentation but with a `\n` at the end.
    sig { params(string: T.nilable(String)).void }
    def printn(string = nil); end

    # Print a string with indentation but without a `\n` at the end.
    sig { params(string: T.nilable(String)).void }
    def printt(string = nil); end

    # Print a string with indentation and `\n` at the end.
    sig { params(string: String).void }
    def printl(string); end

    # @override
    sig { params(nodes: T::Array[Node]).void }
    def visit_all(nodes); end

    # @override
    sig { params(file: File).void }
    def visit_file(file); end

    private

    # @override
    sig { params(node: RBSComment).void }
    def visit_rbs_comment(node); end

    # @override
    sig { params(node: Comment).void }
    def visit_comment(node); end

    # @override
    sig { params(node: BlankLine).void }
    def visit_blank_line(node); end

    # @override
    sig { params(node: Tree).void }
    def visit_tree(node); end

    # @override
    sig { params(node: Module).void }
    def visit_module(node); end

    # @override
    sig { params(node: Class).void }
    def visit_class(node); end

    # @override
    sig { params(node: Struct).void }
    def visit_struct(node); end

    # @override
    sig { params(node: SingletonClass).void }
    def visit_singleton_class(node); end

    sig { params(node: Scope).void }
    def visit_scope(node); end

    sig { params(node: Scope).void }
    def visit_scope_header(node); end

    sig { params(node: Scope).void }
    def visit_scope_body(node); end

    # @override
    sig { params(node: Const).void }
    def visit_const(node); end

    # @override
    sig { params(node: AttrAccessor).void }
    def visit_attr_accessor(node); end

    # @override
    sig { params(node: AttrReader).void }
    def visit_attr_reader(node); end

    # @override
    sig { params(node: AttrWriter).void }
    def visit_attr_writer(node); end

    sig { params(node: Attr).void }
    def visit_attr(node); end

    # @override
    sig { params(node: Method).void }
    def visit_method(node); end

    # @override
    sig { params(node: ReqParam).void }
    def visit_req_param(node); end

    # @override
    sig { params(node: OptParam).void }
    def visit_opt_param(node); end

    # @override
    sig { params(node: RestParam).void }
    def visit_rest_param(node); end

    # @override
    sig { params(node: KwParam).void }
    def visit_kw_param(node); end

    # @override
    sig { params(node: KwOptParam).void }
    def visit_kw_opt_param(node); end

    # @override
    sig { params(node: KwRestParam).void }
    def visit_kw_rest_param(node); end

    # @override
    sig { params(node: BlockParam).void }
    def visit_block_param(node); end

    # @override
    sig { params(node: Include).void }
    def visit_include(node); end

    # @override
    sig { params(node: Extend).void }
    def visit_extend(node); end

    sig { params(node: Mixin).void }
    def visit_mixin(node); end

    # @override
    sig { params(node: Public).void }
    def visit_public(node); end

    # @override
    sig { params(node: Protected).void }
    def visit_protected(node); end

    # @override
    sig { params(node: Private).void }
    def visit_private(node); end

    sig { params(node: Visibility).void }
    def visit_visibility(node); end

    # @override
    sig { params(node: Send).void }
    def visit_send(node); end

    # @override
    sig { params(node: Arg).void }
    def visit_arg(node); end

    # @override
    sig { params(node: KwArg).void }
    def visit_kw_arg(node); end

    # @override
    sig { params(node: Sig).void }
    def visit_sig(node); end

    # @override
    sig { params(node: SigParam).void }
    def visit_sig_param(node); end

    # @override
    sig { params(node: TStruct).void }
    def visit_tstruct(node); end

    # @override
    sig { params(node: TStructConst).void }
    def visit_tstruct_const(node); end

    # @override
    sig { params(node: TStructProp).void }
    def visit_tstruct_prop(node); end

    sig { params(node: TStructField).void }
    def visit_t_struct_field(node); end

    # @override
    sig { params(node: TEnum).void }
    def visit_tenum(node); end

    # @override
    sig { params(node: TEnumBlock).void }
    def visit_tenum_block(node); end

    # @override
    sig { params(node: TypeMember).void }
    def visit_type_member(node); end

    # @override
    sig { params(node: Helper).void }
    def visit_helper(node); end

    # @override
    sig { params(node: MixesInClassMethods).void }
    def visit_mixes_in_class_methods(node); end

    # @override
    sig { params(node: Group).void }
    def visit_group(node); end

    # @override
    sig { params(node: VisibilityGroup).void }
    def visit_visibility_group(node); end

    # @override
    sig { params(node: RequiresAncestor).void }
    def visit_requires_ancestor(node); end

    # @override
    sig { params(node: ConflictTree).void }
    def visit_conflict_tree(node); end

    # @override
    sig { params(node: ScopeConflict).void }
    def visit_scope_conflict(node); end

    sig { params(node: Node).void }
    def print_blank_line_before(node); end

    sig { params(node: Node).void }
    def print_loc(node); end

    sig { params(node: Param, last: T::Boolean).void }
    def print_param_comment_leading_space(node, last:); end

    sig { params(node: SigParam, last: T::Boolean).void }
    def print_sig_param_comment_leading_space(node, last:); end

    sig { params(node: Node).returns(T::Boolean) }
    def oneline?(node); end

    sig { params(node: Sig).void }
    def print_sig_as_line(node); end

    sig { params(node: Sig).void }
    def print_sig_as_block(node); end

    sig { params(node: Sig).returns(T::Array[String]) }
    def sig_modifiers(node); end
  end

  class File
    sig { params(out: T.any(IO, StringIO), indent: Integer, print_locs: T::Boolean, max_line_length: T.nilable(Integer)).void }
    def print(out: $stdout, indent: 0, print_locs: false, max_line_length: nil); end

    sig { params(indent: Integer, print_locs: T::Boolean, max_line_length: T.nilable(Integer)).returns(String) }
    def string(indent: 0, print_locs: false, max_line_length: nil); end
  end

  class Node
    sig { params(out: T.any(IO, StringIO), indent: Integer, print_locs: T::Boolean, max_line_length: T.nilable(Integer)).void }
    def print(out: $stdout, indent: 0, print_locs: false, max_line_length: nil); end

    sig { params(indent: Integer, print_locs: T::Boolean, max_line_length: T.nilable(Integer)).returns(String) }
    def string(indent: 0, print_locs: false, max_line_length: nil); end
  end
end
