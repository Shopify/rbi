# typed: strict
# frozen_string_literal: true

# Printing

# discard remaining signatures

# For attr_writer, Sorbet will prioritize the return type over the argument type in case of mismatch

# If we have an argument type and the return type is void, we prioritize the argument type

# Otherwise, we prioritize the return type

# no-op, we skip the block definition

# no-op, `mixes_in_class_methods` is not supported in RBS

# no-op, `protected` is not supported in RBS

# no-op, arbitrary sends are not supported in RBS

# no-op

# no-op

# `T::Struct.const` is not supported in RBS instead we generate an attribute reader

# `T::Struct.prop` is not supported in RBS instead we generate an attribute accessor

# no-op, we already show them in the scope header

# no-op, we already show them in the scope header

# no-op, we already show them in the scope header

# since we skip them
# since we skip them
# since we skip them
# since we skip them
# since we skip them
# since we skip them
# since we skip them
# since we skip them
# since we skip them

module RBI
  class RBSPrinter < Visitor
    class Error < RBI::Error; end

    sig { returns(T::Boolean) }
    attr_accessor :print_locs, :in_visibility_group

    sig { returns(T.nilable(Node)) }
    attr_reader :previous_node

    sig { returns(Integer) }
    attr_reader :current_indent

    sig { returns(T::Boolean) }
    attr_accessor :positional_names

    sig { params(out: T.any(IO, StringIO), indent: Integer, print_locs: T::Boolean, positional_names: T::Boolean).void }
    def initialize(out: $stdout, indent: 0, print_locs: false, positional_names: true); end

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

    sig { params(node: RBI::Attr, sig: Sig).void }
    def print_attr_sig(node, sig); end

    # @override
    sig { params(node: Method).void }
    def visit_method(node); end

    sig { params(node: RBI::Method, sig: Sig).void }
    def print_method_sig(node, sig); end

    sig { params(node: Sig).void }
    def visit_sig(node); end

    sig { params(node: SigParam).void }
    def visit_sig_param(node); end

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
    sig { params(node: TStruct).void }
    def visit_tstruct(node); end

    # @override
    sig { params(node: TStructConst).void }
    def visit_tstruct_const(node); end

    # @override
    sig { params(node: TStructProp).void }
    def visit_tstruct_prop(node); end

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

    private

    sig { params(node: Node).void }
    def print_blank_line_before(node); end

    sig { params(node: Node).void }
    def print_loc(node); end

    sig { params(node: Method, param: SigParam).void }
    def print_sig_param(node, param); end

    sig { params(node: Param, last: T::Boolean).void }
    def print_param_comment_leading_space(node, last:); end

    sig { params(node: SigParam, last: T::Boolean).void }
    def print_sig_param_comment_leading_space(node, last:); end

    sig { params(node: Node).returns(T::Boolean) }
    def oneline?(node); end

    sig { params(type: T.any(Type, String)).returns(Type) }
    def parse_type(type); end

    # Parse a string containing a `T.let(x, X)` and extract the type
    #
    # Returns `nil` is the string is not a `T.let`.
    sig { params(code: T.nilable(String)).returns(T.nilable(String)) }
    def parse_t_let(code); end
  end

  class TypePrinter
    sig { returns(String) }
    attr_reader :string

    sig { void }
    def initialize; end

    sig { params(node: Type).void }
    def visit(node); end

    sig { params(type: Type::Simple).void }
    def visit_simple(type); end

    sig { params(type: Type::Boolean).void }
    def visit_boolean(type); end

    sig { params(type: Type::Generic).void }
    def visit_generic(type); end

    sig { params(type: Type::Anything).void }
    def visit_anything(type); end

    sig { params(type: Type::Void).void }
    def visit_void(type); end

    sig { params(type: Type::NoReturn).void }
    def visit_no_return(type); end

    sig { params(type: Type::Untyped).void }
    def visit_untyped(type); end

    sig { params(type: Type::SelfType).void }
    def visit_self_type(type); end

    sig { params(type: Type::AttachedClass).void }
    def visit_attached_class(type); end

    sig { params(type: Type::Nilable).void }
    def visit_nilable(type); end

    sig { params(type: Type::ClassOf).void }
    def visit_class_of(type); end

    sig { params(type: Type::All).void }
    def visit_all(type); end

    sig { params(type: Type::Any).void }
    def visit_any(type); end

    sig { params(type: Type::Tuple).void }
    def visit_tuple(type); end

    sig { params(type: Type::Shape).void }
    def visit_shape(type); end

    sig { params(type: Type::Proc).void }
    def visit_proc(type); end

    sig { params(type: Type::TypeParameter).void }
    def visit_type_parameter(type); end

    sig { params(type: Type::Class).void }
    def visit_class(type); end

    private

    sig { params(type_name: String).returns(String) }
    def translate_t_type(type_name); end
  end

  class File
    sig { params(out: T.any(IO, StringIO), indent: Integer, print_locs: T::Boolean).void }
    def rbs_print(out: $stdout, indent: 0, print_locs: false); end

    sig { params(indent: Integer, print_locs: T::Boolean).returns(String) }
    def rbs_string(indent: 0, print_locs: false); end
  end

  class Node
    sig { params(out: T.any(IO, StringIO), indent: Integer, print_locs: T::Boolean, positional_names: T::Boolean).void }
    def rbs_print(out: $stdout, indent: 0, print_locs: false, positional_names: true); end

    sig { params(indent: Integer, print_locs: T::Boolean, positional_names: T::Boolean).returns(String) }
    def rbs_string(indent: 0, print_locs: false, positional_names: true); end
  end

  class Type
    sig { returns(String) }
    def rbs_string; end
  end
end
