# typed: strict
# frozen_string_literal: true

module RBI
  module Validators
    class Sigs < Visitor
      extend T::Sig

      class Error < Validators::Error; end

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
        when TStructField
        end

        visit_all(node.nodes) if node.is_a?(Tree)
      end

      private

      sig { params(re: Regexp, node: Node, name: String).void }
      def validate_sig(re, node, name)
        return if re.match?(name)

        node_kind = node.class.to_s.sub("RBI::", "")
        errors << Error.new("invalid name `#{name}` for #{node_kind}", node: node)
      end
    end
  end
end
