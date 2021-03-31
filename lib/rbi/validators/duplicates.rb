# typed: strict
# frozen_string_literal: true

module RBI
  module Validators
    class Error < RBI::Error; end

    class Duplicates
      extend T::Sig

      sig { params(trees: T::Array[Tree]).returns(T::Boolean) }
      def self.validate(trees)
        validator = Duplicates.new
        validator.validate(trees)
      end

      sig { returns(T::Array[Error]) }
      attr_reader :errors

      sig { void }
      def initialize
        @errors = T.let([], T::Array[Error])
      end

      sig { params(trees: T::Array[Tree]).returns(T::Boolean) }
      def validate(trees)
        index = Index.index(trees)

        index.each do |name, nodes|
          if nodes.size > 1
            # TODO check if defs are incompatibles
            return false
          end
        end

        true
      end
    end
  end
end