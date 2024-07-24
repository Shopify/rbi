# typed: strict
# frozen_string_literal: true

require_relative "visitor.rb"

module RBI
  module RBS
    class RBSToRBIVisitor < ::RBS::AST::Visitor
      extend T::Sig

      sig { returns(RBI::Tree) }
      attr_reader :rbi

      # sig { params(include_foreign: T::Boolean).returns(T::Boolean) }
      # attr_writer :include_foreign

      sig { void }
      def initialize
        super
        @rbi = T.let(RBI::Tree.new, RBI::Tree)
        @scope_stack = T.let([], T::Array[RBI::Scope])
        # @include_foreign = T.let(false, T::Boolean)
        @current_visibility = T.let(:public, Symbol)
      end

      sig { params(node: T.any(::RBS::AST::Members::Base, ::RBS::AST::Declarations::Base)).void }
      def visit(node)
        return if skip_declaration?(node)

        super
      end

      sig { params(member: ::RBS::AST::Members::MethodDefinition).void }
      def visit_member_method_definition(member)
        comments = rbi_comments(member.comment)
        method_type = member.overloads.first.method_type
        visibility = type_converter.visibility(member.visibility || @current_visibility)

        abstract = comments.any? { |comment| comment.text.chomp == "@abstract" }
        comments.reject! { |comment| comment.text.chomp == "@abstract" } if abstract

        current_scope << RBI::Method.new(
          member.name.to_s,
          is_singleton: member.singleton?,
          visibility: visibility,
          comments: comments,
        ) do |method|
          attach_signature_and_params(method, method_type, abstract: abstract)
        end
      end

      sig { params(member: ::RBS::AST::Members::Alias).void }
      def visit_member_alias(member)
        current_scope << Const.new(member.new_name.to_s, "T.type_alias { #{member.old_name}")
      end

      sig { params(member: ::RBS::AST::Members::AttrReader).void }
      def visit_member_attr_reader(member)
        current_scope << AttrReader.new(member.name.to_s) do |node|
          node.visibility = type_converter.visibility(member.visibility || @current_visibility)
          node.sigs << RBI::Sig.new do |sig|
            sig.return_type = type_converter.to_string(member.type)
          end
        end
      end

      sig { params(member: ::RBS::AST::Members::AttrWriter).void }
      def visit_member_attr_writer(member)
        current_scope << AttrWriter.new(member.name.to_sym) do |node|
          node.visibility = type_converter.visibility(member.visibility || @current_visibility)
          node.sigs << RBI::Sig.new do |sig|
            type = type_converter.to_string(member.type)
            sig.params << RBI::SigParam.new(member.name.to_s, type)
            sig.return_type = type
          end
        end
      end

      sig { params(member: ::RBS::AST::Members::AttrAccessor).void }
      def visit_member_attr_accessor(member)
        current_scope << AttrAccessor.new(member.name.to_s) do |node|
          node.visibility = type_converter.visibility(member.visibility || @current_visibility)
          node.sigs << RBI::Sig.new do |sig|
            sig.return_type = type_converter.to_string(member.type)
          end
        end
      end

      sig { params(member: ::RBS::AST::Members::Private).void }
      def visit_member_private(member)
        @current_visibility = :private
      end

      sig { params(member: ::RBS::AST::Members::Public).void }
      def visit_member_public(member)
        @current_visibility = :public
      end

      sig { params(member: ::RBS::AST::Members::Include).void }
      def visit_member_include(member)
        current_scope << Include.new(member.name.to_s)
        # @converter.push_foreign_name(member.name)
      end

      alias_method :visit_member_prepend, :visit_member_include

      sig { params(member: ::RBS::AST::Members::Extend).void }
      def visit_member_extend(member)
        current_scope << Extend.new(member.name.to_s)
        # @converter.push_foreign_name(member.name)
      end

      sig { params(decl: ::RBS::AST::Declarations::Class).void }
      def visit_declaration_class(decl)
        scope = Class.new(
          decl.name.to_s,
          superclass_name: decl.super_class&.name&.to_s,
          comments: rbi_comments(decl.comment),
        )
        current_scope << scope
        add_type_variables(scope, decl)

        visit_scope(scope) { super }
      end

      sig { params(decl: ::RBS::AST::Declarations::Module).void }
      def visit_declaration_module(decl)
        # We don't want to generate a definition for ::Enumerable ever,
        # since it crashes Sorbet, if we do so.
        return if decl.name.to_s == "::Enumerable"

        scope = Module.new(decl.name.to_s, comments: rbi_comments(decl.comment))
        current_scope << scope
        add_type_variables(scope, decl)

        visit_scope(scope) { super }
      end

      alias_method :visit_declaration_interface, :visit_declaration_module

      sig { params(decl: ::RBS::AST::Declarations::Constant).void }
      def visit_declaration_constant(decl)
        const = Const.new(
          decl.name.to_s,
          "T.let(T.unsafe(nil), #{type_converter.convert(decl.type)})",
          comments: rbi_comments(decl.comment),
        )
        current_scope << const
      end

      sig { params(decl: ::RBS::AST::Declarations::TypeAlias).void }
      def visit_declaration_type_alias(decl)
        name = decl.name.to_s
        value = type_converter.convert(decl.type).to_s
        value = "T.untyped" if value.include?(name)

        const = Const.new(name, "T.type_alias { #{value} }")
        current_scope << const
      end

      private

      sig { params(scope: RBI::Scope, block: T.proc.void).void }
      def visit_scope(scope, &block)
        @current_visibility = :public
        @scope_stack << scope

        block.call

        @scope_stack.pop
      end

      sig { returns(RBI::Tree) }
      def current_scope
        @scope_stack.last || @rbi
      end

      sig { params(node: T.any(::RBS::AST::Declarations::Base, ::RBS::AST::Members::Base)).returns(T::Boolean) }
      def skip_declaration?(node)
        # ::RBS::AST::Declarations::Base === node &&
        #   !@include_foreign &&
        #   @converter.skipped?(node)
        false
      end

      sig do
        params(
          scope: RBI::Scope,
          decl: T.any(
            ::RBS::AST::Declarations::Class,
            ::RBS::AST::Declarations::Interface,
            ::RBS::AST::Declarations::Module,
          ),
        ).void
      end
      def add_type_variables(scope, decl)
        scope << Extend.new("T::Generic") unless decl.type_params.empty?

        decl.type_params.each do |type_param|
          scope << Const.new(type_param.name.to_s, "type_member")
        end

        if decl.is_a?(::RBS::AST::Declarations::Class)
          superclass = decl.super_class
          if superclass
            # superclass_decl = @converter.decl_for_class_name(superclass.name)
            superclass_decl = superclass.name
            nil unless superclass_decl

            # superclass_decl.type_params.zip(superclass.args).each do |type_param, arg|
            #   value = "type_member { { fixed: #{type_converter.to_string(arg)} } }"
            #   scope << Const.new(type_param.name.to_s, value)
            # end
          end
        end
      end

      sig do
        params(
          method: RBI::Method,
          method_type: ::RBS::MethodType,
          abstract: T::Boolean,
        ).void
      end
      def attach_signature_and_params(method, method_type, abstract:)
        tc = type_converter.with_type_params(method_type.type_params)

        parameters = tc.convert_parameters(method_type.type, method_type.block)
        return_type = tc.to_string(method_type.type.return_type)

        method.sigs << sig = RBI::Sig.new(is_abstract: abstract) do |sig|
          tc.type_params.each do |type_param|
            sig.type_params << type_param.to_s
          end

          # Return type
          sig.return_type = if method.name.to_s == "initialize"
            "void"
          elsif return_type == "T.attached_class" && !method.is_singleton
            "T.untyped"
          else
            return_type
          end
        end

        parameters.each do |param|
          name = param.name

          rbi_param = case param.kind
          when :req
            RBI::ReqParam.new(name)
          when :opt
            RBI::OptParam.new(name, "T.unsafe(nil)")
          when :rest
            RBI::RestParam.new(name)
          when :keyreq
            RBI::KwParam.new(name)
          when :key
            RBI::KwOptParam.new(name, "T.unsafe(nil)")
          when :keyrest
            RBI::KwRestParam.new(name)
          when :block
            RBI::BlockParam.new(name)
          end

          sig << RBI::SigParam.new(param.name, tc.to_string(param.type))
          method << T.must(rbi_param)
        end
      end

      sig { params(rbs_comment: T.nilable(::RBS::AST::Comment)).returns(T::Array[RBI::Comment]) }
      def rbi_comments(rbs_comment)
        return [] unless rbs_comment

        rbs_comment.string.lines.map do |line|
          RBI::Comment.new(line)
        end
      end

      sig { returns(TypeConverter) }
      def type_converter
        @type_converter ||= T.let(TypeConverter.new, T.nilable(TypeConverter))
      end
    end
  end
end
