# typed: strict
# frozen_string_literal: true

module RBI
  module Validators
    class Error < RBI::Error
      extend T::Sig

      sig { returns(String) }
      attr_reader :message

      sig { returns(T::Array[Section]) }
      attr_reader :sections

      sig { params(message: String, sections: T::Array[Section]).void }
      def initialize(message, sections: [])
        super()
        @message = message
        @sections = sections
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
