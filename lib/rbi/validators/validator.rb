# typed: strict
# frozen_string_literal: true

module RBI
  class Validators
    class Model < Visitor
      extend T::Sig

      sig { override.params(node: T.nilable(Node)).void }
      def visit(node)
        node.validate_model(node)
      end
    end

    class Node
      extend T::Sig
    end

    class Tree
      extend T::Sig

      sig { void }
      def validate
        Validator.new.visit(self)
      end
    end
  end
end
