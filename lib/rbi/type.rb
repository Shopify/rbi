# typed: strict
# frozen_string_literal: true

module RBI
  class Type
    extend T::Sig
    extend T::Helpers

    abstract!

    class Simple < Type
      extend T::Sig

      sig { returns(String) }
      attr_reader :name

      sig { params(name: String).void }
      def initialize(name)
        super()
        @name = name
      end

      sig { override.params(other: Type).returns(T::Boolean) }
      def ==(other)
        other.is_a?(Simple) && @name == other.name
      end

      sig { override.returns(String) }
      def to_rbi
        @name
      end
    end

    class Generic < Type
      extend T::Sig

      sig { params(name: String, params: Type).void }
      def initialize(name, *params)
        super()
        @name = name
        @params = T.let(params, T::Array[Type])
      end

      sig { override.returns(String) }
      def to_rbi
        "#{@name}[#{@params.map(&:to_rbi).join(", ")}]"
      end
    end

    class Anything < Type
      extend T::Sig

      sig { override.returns(String) }
      def to_rbi
        "T.anything"
      end
    end

    class Void < Type
      extend T::Sig

      sig { override.returns(String) }
      def to_rbi
        "void"
      end
    end

    class Untyped < Type
      extend T::Sig

      sig { override.returns(String) }
      def to_rbi
        "T.untyped"
      end
    end

    class SelfType < Type
      extend T::Sig

      sig { override.returns(String) }
      def to_rbi
        "T.self_type"
      end
    end

    class AttachedClass < Type
      extend T::Sig

      sig { override.returns(String) }
      def to_rbi
        "T.attached_class"
      end
    end

    class Nilable < Type
      extend T::Sig

      sig { returns(Type) }
      attr_reader :type

      sig { params(type: Type).void }
      def initialize(type)
        super()
        @type = type
      end

      sig { override.returns(String) }
      def to_rbi
        "T.nilable(#{@type.to_rbi})"
      end
    end

    class Composite < Type
      extend T::Sig
      extend T::Helpers

      abstract!

      sig { returns(T::Array[Type]) }
      attr_reader :types

      sig { params(types: Type).void }
      def initialize(*types)
        super()
        @types = T.let(types, T::Array[Type])
      end
    end

    class ClassOf < Type
      extend T::Sig

      sig { params(type: Simple).void }
      def initialize(type)
        super()
        @type = type
      end

      sig { override.returns(String) }
      def to_rbi
        "T.class_of(#{@type.to_rbi})"
      end
    end

    class All < Composite
      extend T::Sig

      sig { override.returns(String) }
      def to_rbi
        raise if @types.size < 2

        "T.all(#{@types.map(&:to_rbi).join(", ")})"
      end
    end

    class Any < Composite
      extend T::Sig

      sig { override.returns(String) }
      def to_rbi
        raise if @types.size < 2

        "T.any(#{@types.map(&:to_rbi).join(", ")})"
      end

      sig { returns(T::Boolean) }
      def nilable?
        @types.any? { |type| type.nilable? || (type.is_a?(Simple) && type.name == "NilClass") }
      end
    end

    class << self
      extend T::Sig

      sig { params(name: String).returns(Simple) }
      def simple(name)
        RubyVM::InstructionSequence.compile("class self::#{name.delete_prefix("::")}; end")

        Simple.new(name)
      rescue SyntaxError
        raise NameError, "Invalid type name: #{name}"
      end

      sig { params(name: String, params: Type).returns(Generic) }
      def generic(name, *params)
        T.unsafe(Generic).new(name, *params)
      end

      sig { returns(Anything) }
      def anything
        Anything.new
      end

      sig { returns(Void) }
      def void
        Void.new
      end

      sig { returns(Untyped) }
      def untyped
        Untyped.new
      end

      sig { returns(SelfType) }
      def self_type
        SelfType.new
      end

      sig { returns(AttachedClass) }
      def attached_class
        AttachedClass.new
      end

      # Since we transform types such as `T.nilable(T.untyped)` into `T.untyped`, this method may return something else
      # than a `Nilable`.
      sig { params(type: Type).returns(Type) }
      def nilable(type)
        return type if type.is_a?(Untyped)

        Nilable.new(type)
      end

      sig { params(type: Simple).returns(ClassOf) }
      def class_of(type)
        ClassOf.new(type)
      end

      # Since we transform types such as `T.all(String, String)` into `String`, this method may return something else
      # than a `All`.
      sig { params(types: Type).returns(Type) }
      def all(*types)
        flattened = types.flat_map do |type|
          case type
          when All
            type.types
          else
            type
          end
        end.uniq

        if flattened.size == 1
          flattened.first
        else
          T.unsafe(All).new(*flattened)
        end
      end

      # Since we transform types such as `T.any(String, NilClass)` into `T.nilable(String)`, this method may return
      # something else than a `Any`.
      sig { params(types: Type).returns(Type) }
      def any(*types)
        flattened = types.flat_map do |type|
          case type
          when Any
            type.types
          else
            type
          end
        end

        is_nilable = T.let(false, T::Boolean)

        types = flattened.filter_map do |type|
          case type
          when Simple
            if type.name == "NilClass"
              is_nilable = true
              nil
            else
              type
            end
          when Nilable
            is_nilable = true
            type.type
          else
            type
          end
        end.uniq

        has_true_class = types.any? { |type| type.is_a?(Simple) && type.name == "TrueClass" }
        has_false_class = types.any? { |type| type.is_a?(Simple) && type.name == "FalseClass" }

        if has_true_class && has_false_class
          types = types.reject { |type| type.is_a?(Simple) && (type.name == "TrueClass" || type.name == "FalseClass") }
          types << simple("T::Boolean")
        end

        type = if types.size == 1
          types.first
        else
          T.unsafe(Any).new(*types)
        end

        if is_nilable
          nilable(type)
        else
          type
        end
      end

      # We mark the constructor as `protected` because we want to force the use of factories on `Type` to create types
      protected :new
    end

    sig { void }
    def initialize
      @nilable = T.let(false, T::Boolean)
    end

    sig { returns(Type) }
    def nilable
      Type.nilable(self)
    end

    sig { returns(T::Boolean) }
    def nilable?
      is_a?(Nilable)
    end

    sig { abstract.params(other: Type).returns(T::Boolean) }
    def ==(other); end

    sig { params(other: Type).returns(T::Boolean) }
    def eql?(other)
      self == other
    end

    sig { override.returns(Integer) }
    def hash
      to_rbi.hash
    end

    sig { abstract.returns(String) }
    def to_rbi; end
  end
end
