# typed: strict
# frozen_string_literal: true

module RBI
  module Validators
    class Names < Visitor
      extend T::Sig

      class Error < Validators::Error; end

      RE_CONST = /^((::)?[A-Z][a-zA-Z0-9_]*)+$/
      RE_IDENT = /^[a-zA-Z_][a-zA-Z0-9_]*$/
      RE_PARAM = /^[a-z_][a-zA-Z0-9_]*$/

      sig { returns(T::Array[Error]) }
      attr_reader :errors

      sig { void }
      def initialize
        @errors = T.let([], T::Array[Error])
      end

      sig { override.params(node: T.nilable(Node)).void }
      def visit(node)
        return unless node

        case node
        when Const, Module, Struct
          validate_name(RE_CONST, node, node.name)
        when Class
          validate_name(RE_CONST, node, node.name)
          superclass_name = node.superclass_name
          validate_name(RE_CONST, node, superclass_name) if superclass_name
        when Method
          validate_name(RE_IDENT, node, node.name)
          node.params.each { |param| validate_name(RE_PARAM, param, param.name.to_s) }
        when Attr
          node.names.each { |name| validate_name(RE_PARAM, node, name.to_s) }
        when Mixin, TEnumBlock
          node.names.each { |name| validate_name(RE_CONST, node, name.to_s) }
        when TStructField
          validate_name(RE_IDENT, node, node.name.to_s)
        end

        visit_all(node.nodes) if node.is_a?(Tree)
      end

      private

      sig { params(re: Regexp, node: Node, name: String).void }
      def validate_name(re, node, name)
        return if re.match?(name)

        node_kind = node.class.to_s.sub("RBI::", "")
        errors << Error.new("invalid name `#{name}` for #{node_kind}", node: node)
      end
    end
  end
end
