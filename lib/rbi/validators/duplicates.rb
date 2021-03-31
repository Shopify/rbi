# typed: strict
# frozen_string_literal: true

module RBI
  module Validators
    class Duplicates
      extend T::Sig

      sig { params(trees: T::Array[Tree]).returns([T::Boolean, T::Array[Error]]) }
      def self.validate(trees)
        validator = Duplicates.new
        [validator.validate(trees), validator.errors]
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

        index.each do |_name, nodes|
          next if nodes.size <= 1
          next unless nodes.first.is_a?(Method)

          methods = T.cast(nodes.select { |node| node.is_a?(Method) }, T::Array[Method])
          @errors << Error.new(methods)
          return false
        end

        true
      end

      class Error < RBI::Error
        extend T::Sig

        sig { params(nodes: T::Array[Method]).void }
        def initialize(nodes)
          super()
          @name = T.let(T.must(nodes.first).name, String)
          @nodes = nodes
        end

        sig { returns(String) }
        def to_s
          "Duplicate definitions found for `#{@name}`: #{@nodes.map(&:loc).join(",")}"
        end
      end
    end
  end
end
