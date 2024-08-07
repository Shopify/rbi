# typed: strict
# frozen_string_literal: true

module RBI
  class VisitorError < Error; end

  class Visitor
    extend T::Helpers
    extend T::Sig

    abstract!

    sig { params(node: T.nilable(Node)).void }
    def visit(node)
      return unless node

      case node
      when BlankLine
        visit_blank_line(node)
      when Comment
        visit_comment(node)
      when TEnum
        visit_tenum(node)
      when TStruct
        visit_tstruct(node)
      when Module
        visit_module(node)
      when Class
        visit_class(node)
      when SingletonClass
        visit_singleton_class(node)
      when Struct
        visit_struct(node)
      when Group
        visit_group(node)
      when VisibilityGroup
        visit_visibility_group(node)
      when ConflictTree
        visit_conflict_tree(node)
      when ScopeConflict
        visit_scope_conflict(node)
      when TEnumBlock
        visit_tenum_block(node)
      when Tree
        visit_tree(node)
      when Const
        visit_const(node)
      when AttrAccessor
        visit_attr_accessor(node)
      when AttrReader
        visit_attr_reader(node)
      when AttrWriter
        visit_attr_writer(node)
      when Method
        visit_method(node)
      when ReqParam
        visit_req_param(node)
      when OptParam
        visit_opt_param(node)
      when RestParam
        visit_rest_param(node)
      when KwParam
        visit_kw_param(node)
      when KwOptParam
        visit_kw_opt_param(node)
      when KwRestParam
        visit_kw_rest_param(node)
      when BlockParam
        visit_block_param(node)
      when Include
        visit_include(node)
      when Extend
        visit_extend(node)
      when Public
        visit_public(node)
      when Protected
        visit_protected(node)
      when Private
        visit_private(node)
      when Send
        visit_send(node)
      when KwArg
        visit_kw_arg(node)
      when Arg
        visit_arg(node)
      when Sig
        visit_sig(node)
      when SigParam
        visit_sig_param(node)
      when TStructConst
        visit_tstruct_const(node)
      when TStructProp
        visit_tstruct_prop(node)
      when Helper
        visit_helper(node)
      when TypeMember
        visit_type_member(node)
      when MixesInClassMethods
        visit_mixes_in_class_methods(node)
      when RequiresAncestor
        visit_requires_ancestor(node)
      else
        raise VisitorError, "Unhandled node: #{node.class}"
      end
    end

    sig { params(nodes: T::Array[Node]).void }
    def visit_all(nodes)
      nodes.each { |node| visit(node) }
    end

    sig { params(file: File).void }
    def visit_file(file)
      visit(file.root)
    end

    private

    sig { params(node: Comment).void }
    def visit_comment(node); end

    sig { params(node: BlankLine).void }
    def visit_blank_line(node); end

    sig { params(node: Module).void }
    def visit_module(node); end

    sig { params(node: Class).void }
    def visit_class(node); end

    sig { params(node: SingletonClass).void }
    def visit_singleton_class(node); end

    sig { params(node: Struct).void }
    def visit_struct(node); end

    sig { params(node: Tree).void }
    def visit_tree(node); end

    sig { params(node: Const).void }
    def visit_const(node); end

    sig { params(node: AttrAccessor).void }
    def visit_attr_accessor(node); end

    sig { params(node: AttrReader).void }
    def visit_attr_reader(node); end

    sig { params(node: AttrWriter).void }
    def visit_attr_writer(node); end

    sig { params(node: Method).void }
    def visit_method(node); end

    sig { params(node: ReqParam).void }
    def visit_req_param(node); end

    sig { params(node: OptParam).void }
    def visit_opt_param(node); end

    sig { params(node: RestParam).void }
    def visit_rest_param(node); end

    sig { params(node: KwParam).void }
    def visit_kw_param(node); end

    sig { params(node: KwOptParam).void }
    def visit_kw_opt_param(node); end

    sig { params(node: KwRestParam).void }
    def visit_kw_rest_param(node); end

    sig { params(node: BlockParam).void }
    def visit_block_param(node); end

    sig { params(node: Include).void }
    def visit_include(node); end

    sig { params(node: Extend).void }
    def visit_extend(node); end

    sig { params(node: Public).void }
    def visit_public(node); end

    sig { params(node: Protected).void }
    def visit_protected(node); end

    sig { params(node: Private).void }
    def visit_private(node); end

    sig { params(node: Send).void }
    def visit_send(node); end

    sig { params(node: Arg).void }
    def visit_arg(node); end

    sig { params(node: KwArg).void }
    def visit_kw_arg(node); end

    sig { params(node: Sig).void }
    def visit_sig(node); end

    sig { params(node: SigParam).void }
    def visit_sig_param(node); end

    sig { params(node: TStruct).void }
    def visit_tstruct(node); end

    sig { params(node: TStructConst).void }
    def visit_tstruct_const(node); end

    sig { params(node: TStructProp).void }
    def visit_tstruct_prop(node); end

    sig { params(node: TEnum).void }
    def visit_tenum(node); end

    sig { params(node: TEnumBlock).void }
    def visit_tenum_block(node); end

    sig { params(node: Helper).void }
    def visit_helper(node); end

    sig { params(node: TypeMember).void }
    def visit_type_member(node); end

    sig { params(node: MixesInClassMethods).void }
    def visit_mixes_in_class_methods(node); end

    sig { params(node: RequiresAncestor).void }
    def visit_requires_ancestor(node); end

    sig { params(node: Group).void }
    def visit_group(node); end

    sig { params(node: VisibilityGroup).void }
    def visit_visibility_group(node); end

    sig { params(node: ConflictTree).void }
    def visit_conflict_tree(node); end

    sig { params(node: ScopeConflict).void }
    def visit_scope_conflict(node); end
  end
end
