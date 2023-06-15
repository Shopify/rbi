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

    class Boolean < Type
      extend T::Sig

      sig { override.returns(String) }
      def to_rbi
        "T::Boolean"
      end
    end

    class Verbatim < Type
      extend T::Sig

      sig { params(rbi_string: String).void }
      def initialize(rbi_string)
        super()
        @rbi_string = rbi_string
      end

      sig { override.returns(String) }
      def to_rbi
        @rbi_string
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

      sig { params(types: T::Array[Type]).void }
      def initialize(types)
        super()
        @types = types
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
        "T.all(#{@types.map(&:to_rbi).join(", ")})"
      end
    end

    class Any < Composite
      extend T::Sig

      sig { override.returns(String) }
      def to_rbi
        "T.any(#{@types.map(&:to_rbi).join(", ")})"
      end

      sig { returns(T::Boolean) }
      def nilable?
        @types.any? { |type| type.nilable? || (type.is_a?(Simple) && type.name == "NilClass") }
      end
    end

    class Tuple < Type
      extend T::Sig

      sig { params(types: T::Array[Type]).void }
      def initialize(types)
        super()
        @types = types
      end

      sig { override.returns(String) }
      def to_rbi
        "[#{@types.map(&:to_rbi).join(", ")}]"
      end
    end

    class Shape < Type
      extend T::Sig

      sig { params(types: T::Hash[Symbol, Type]).void }
      def initialize(types)
        super()
        @types = types
      end

      sig { override.returns(String) }
      def to_rbi
        "{#{@types.map { |name, type| "#{name}: #{type.to_rbi}" }.join(", ")}}"
      end
    end

    class Proc < Type
      sig { void }
      def initialize
        super()
        @params = T.let({}, T::Hash[Symbol, Type])
        @returns = T.let(Type.void, Type)
        @bind = T.let(nil, T.nilable(Type))
      end

      sig { params(params: Type).returns(T.self_type) }
      def params(**params)
        @params = params
        self
      end

      sig { params(type: T.untyped).returns(T.self_type) }
      def returns(type)
        @returns = type
        self
      end

      sig { returns(T.self_type) }
      def void
        @returns = RBI::Type.void
        self
      end

      sig { params(type: T.untyped).returns(T.self_type) }
      def bind(type)
        @bind = type
        self
      end

      sig { override.returns(String) }
      def to_rbi
        rbi = +"T.proc"

        if @bind
          rbi << ".bind(#{@bind})"
        end

        unless @params.empty?
          rbi << ".params("
          rbi << @params.map { |name, type| "#{name}: #{type.to_rbi}" }.join(", ")
          rbi << ")"
        end

        rbi << case @returns
        when Void
          ".void"
        else
          ".returns(#{@returns})"
        end

        rbi
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

      sig { params(rbi_string: String).returns(RBI::Type::Verbatim) }
      def verbatim(rbi_string)
        Verbatim.new(rbi_string)
      end

      sig { params(name: String, params: T.any(Type, T::Array[Type])).returns(Generic) }
      def generic(name, *params)
        T.unsafe(Generic).new(name, *params.flatten)
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

      sig { returns(Boolean) }
      def boolean
        Boolean.new
      end

      # Since we transform types such as `T.nilable(T.untyped)` into `T.untyped`, this method may return something else
      # than a `Nilable`.
      sig { params(type: Type).returns(Type) }
      def nilable(type)
        return type if type.is_a?(Untyped)

        if type.nilable?
          type
        else
          Nilable.new(type)
        end
      end

      sig { params(type: Simple).returns(ClassOf) }
      def class_of(type)
        ClassOf.new(type)
      end

      sig { params(types: T.any(Type, T::Array[Type])).returns(Tuple) }
      def tuple(*types)
        Tuple.new(types.flatten)
      end

      sig { params(hash_types: T::Hash[Symbol, Type], types: Type).returns(Shape) }
      def shape(hash_types = {}, **types)
        types = hash_types.merge(types)

        Shape.new(types)
      end

      sig { returns(Proc) }
      def proc
        Proc.new
      end

      # Since we transform types such as `T.all(String, String)` into `String`, this method may return something else
      # than a `All`.
      sig { params(types: T.any(Type, T::Array[Type])).returns(Type) }
      def all(*types)
        flattened = types.flatten.flat_map do |type|
          case type
          when All
            type.types
          else
            type
          end
        end.uniq

        if flattened.size == 1
          T.must(flattened.first)
        else
          raise ArgumentError, "RBI::Type.all should have at least 2 types supplied" if flattened.size < 2

          All.new(flattened)
        end
      end

      # Since we transform types such as `T.any(String, NilClass)` into `T.nilable(String)`, this method may return
      # something else than a `Any`.
      sig { params(types: T.any(Type, T::Array[Type])).returns(Type) }
      def any(*types)
        flattened = types.flatten.flat_map do |type|
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
          types << boolean
        end

        type = case types.size
        when 0
          if is_nilable
            is_nilable = false
            simple("NilClass")
          else
            raise ArgumentError, "RBI::Type.any should have at least 2 types supplied"
          end
        when 1
          T.must(types.first)
        else
          Any.new(types)
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

    sig { returns(Type) }
    def non_nilable
      case self
      when Nilable
        type
      else
        self
      end
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

    sig { override.returns(String) }
    def to_s
      to_rbi
    end
  end
end
