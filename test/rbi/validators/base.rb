# typed: strict
# frozen_string_literal: true

module RBI
  module Validators
    class Error < RBI::Error
      extend T::Sig

      sig { returns(Node) }
      attr_reader :node

      sig { params(message: String, node: Node).void }
      def initialize(message, node:)
        @node = node
        super(message)
      end
    end

    class Base < Visitor
      extend T::Sig
      extend T::Helpers

      abstract!

      sig { returns(T::Array[Error]) }
      attr_reader :errors

      sig { void }
      def initialize
        @errors = T.let([], T::Array[Error])
      end
    end
  end
end
