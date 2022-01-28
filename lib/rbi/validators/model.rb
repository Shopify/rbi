# typed: strict
# frozen_string_literal: true

module RBI
  module Validators
    class Model < Visitor
      extend T::Sig

      class Error < T::Struct

      end

      sig { returns(T::Array[Error]) }
      attr_reader :errors

      sig { void }
      def initialize
        @errors = T.let([], T::Array[Error])
      end

      sig { override.params(node: T.nilable(Node)).void }
      def visit(node)
        return unless node
        node.validate_model(self)
      end
    end
  end

  class Node
    extend T::Sig

    sig { params(validator: Validators::Model).void }
    def validate_model(validator)
      true
    end
  end

  class Tree
    extend T::Sig

    sig { params(validator: Validators::Model).void }
    def validate_model(validator)
      validator.visit_all(nodes)
    end
  end

  class Scope
    extend T::Sig

    sig { params(validator: Validators::Model).void }
    def validate_model(validator)
      # TODO check name
      super
    end
  end
end
