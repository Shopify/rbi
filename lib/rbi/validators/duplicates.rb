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

        ret = T.let(true, T::Boolean)
        index.each do |name, nodes|
          next if nodes.size <= 1

          first_node = nodes.first
          if first_node.is_a?(Method)
            err = Validators::Error.new("Duplicate definitions for `#{first_node.name}`")
          elsif first_node.is_a?(Send)
            method_name = T.must(T.must(name.match(/#(.*)/))[1]).delete_suffix("=")
            err = Validators::Error.new("Duplicate definitions for `#{method_name}`")
          else
            next
          end

          nodes.each do |node|
            next unless node.is_a?(Method) || node.is_a?(Send)

            err.add_section(loc: node.loc)
          end
          @errors << err

          ret = false
        end

        ret
      end
    end
  end
end
