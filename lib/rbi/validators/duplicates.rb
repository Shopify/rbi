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

          method = T.cast(nodes.first, Method)
          err = Error.new("Duplicate definitions for `#{method.name}`")
          nodes.each do |node|
            next unless node.is_a?(Method)

            err.add_section(loc: node.loc)
          end
          @errors << err

          return false
        end

        true
      end

      class Error < RBI::Error
        extend T::Sig

        sig { returns(String) }
        attr_reader :message

        sig { returns(T::Array[Section]) }
        attr_reader :sections

        sig { params(message: String).void }
        def initialize(message)
          super()
          @message = message
          @sections = T.let([], T::Array[Section])
        end

        sig { params(section: Section).void }
        def <<(section)
          @sections << section
        end

        sig { params(loc: T.nilable(Loc)).void }
        def add_section(loc: nil)
          self << Section.new(loc: loc)
        end

        class Section
          extend T::Sig

          sig { returns(T.nilable(Loc)) }
          attr_reader :loc

          sig { params(loc: T.nilable(Loc)).void }
          def initialize(loc: nil)
            @loc = loc
          end
        end
      end
    end
  end
end
