# typed: strict
# frozen_string_literal: true

# Modify the original sig to correct the name, and remove the return type

module RBI
  class UnexpectedMultipleSigsError < Error
    sig { returns(Node) }
    attr_reader :node

    sig { params(node: Node).void }
    def initialize(node); end
  end

  module Rewriters
    class AttrToMethods < Visitor
      # @override
      sig { params(node: T.nilable(Node)).void }
      def visit(node); end

      private

      sig { params(node: Node, with: Array).void }
      def replace(node, with:); end
    end
  end

  class Tree
    sig { void }
    def replace_attributes_with_methods!; end
  end

  class Attr
    sig { abstract.returns(T::Array[Method]) }
    def convert_to_methods; end

    private

    # @final
    sig { returns([T.nilable(Sig), T.nilable(T.any(Type, String))]) }
    def parse_sig; end

    sig { params(name: String, sig: T.nilable(Sig), visibility: Visibility, loc: T.nilable(Loc), comments: Array).returns(Method) }
    def create_getter_method(name, sig, visibility, loc, comments); end

    # rubocop:disable Metrics/ParameterLists
    sig { params(name: String, sig: T.nilable(Sig), attribute_type: T.nilable(T.any(Type, String)), visibility: Visibility, loc: T.nilable(Loc), comments: Array).returns(Method) }
    def create_setter_method(name, sig, attribute_type, visibility, loc, comments); end
  end

  class AttrAccessor
    # @override
    sig { returns(Array) }
    def convert_to_methods; end
  end

  class AttrReader
    # @override
    sig { returns(Array) }
    def convert_to_methods; end
  end

  class AttrWriter
    # @override
    sig { returns(Array) }
    def convert_to_methods; end
  end
end
