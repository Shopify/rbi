# typed: strict
# frozen_string_literal: true

module RBI
  # The base class for all RBI types.
  class Type
    extend T::Sig
    extend T::Helpers

    abstract!

    # Simple

    # A type that represents a simple class name like `String` or `Foo`.
    #
    # It can also be a qualified name like `::Foo` or `Foo::Bar`.
    class Simple < Type
      extend T::Sig

      sig { returns(String) }
      attr_reader :name

      sig { params(name: String).void }
      def initialize(name)
        super()
        @name = name
      end

      sig { override.params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        Simple === other && @name == other.name
      end

      sig { override.returns(String) }
      def to_rbi
        @name
      end
    end

    # Literals

    # `T.anything`.
    class Anything < Type
      extend T::Sig

      sig { override.params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        Anything === other
      end

      sig { override.returns(String) }
      def to_rbi
        "T.anything"
      end
    end

    # `T.attached_class`.
    class AttachedClass < Type
      extend T::Sig

      sig { override.params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        AttachedClass === other
      end

      sig { override.returns(String) }
      def to_rbi
        "T.attached_class"
      end
    end

    # `T::Boolean`.
    class Boolean < Type
      extend T::Sig

      sig { override.params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        Boolean === other
      end

      sig { override.returns(String) }
      def to_rbi
        "T::Boolean"
      end
    end

    # `T.noreturn`.
    class NoReturn < Type
      extend T::Sig

      sig { override.params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        NoReturn === other
      end

      sig { override.returns(String) }
      def to_rbi
        "T.noreturn"
      end
    end

    # `T.self_type`.
    class SelfType < Type
      extend T::Sig

      sig { override.params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        SelfType === other
      end

      sig { override.returns(String) }
      def to_rbi
        "T.self_type"
      end
    end

    # `T.untyped`.
    class Untyped < Type
      extend T::Sig

      sig { override.params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        Untyped === other
      end

      sig { override.returns(String) }
      def to_rbi
        "T.untyped"
      end
    end

    # `void`.
    class Void < Type
      extend T::Sig

      sig { override.params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        Void === other
      end

      sig { override.returns(String) }
      def to_rbi
        "void"
      end
    end

    # Composites

    # The class of another type like `T::Class[Foo]`.
    class Class < Type
      extend T::Sig

      sig { returns(Type) }
      attr_reader :type

      sig { params(type: Type).void }
      def initialize(type)
        super()
        @type = type
      end

      sig { override.params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        Class === other && @type == other.type
      end

      sig { override.returns(String) }
      def to_rbi
        "T::Class[#{@type}]"
      end
    end

    # The singleton class of another type like `T.class_of(Foo)`.
    class ClassOf < Type
      extend T::Sig

      sig { returns(Simple) }
      attr_reader :type

      sig { returns(T.nilable(Type)) }
      attr_reader :type_parameter

      sig { params(type: Simple, type_parameter: T.nilable(Type)).void }
      def initialize(type, type_parameter = nil)
        super()
        @type = type
        @type_parameter = type_parameter
      end

      sig { override.params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        ClassOf === other && @type == other.type && @type_parameter == other.type_parameter
      end

      sig { override.returns(String) }
      def to_rbi
        if @type_parameter
          "T.class_of(#{@type.to_rbi})[#{@type_parameter.to_rbi}]"
        else
          "T.class_of(#{@type.to_rbi})"
        end
      end
    end

    # A type that can be `nil` like `T.nilable(String)`.
    class Nilable < Type
      extend T::Sig

      sig { returns(Type) }
      attr_reader :type

      sig { params(type: Type).void }
      def initialize(type)
        super()
        @type = type
      end

      sig { override.params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        Nilable === other && @type == other.type
      end

      sig { override.returns(String) }
      def to_rbi
        "T.nilable(#{@type.to_rbi})"
      end
    end

    # A type that is composed of multiple types like `T.all(String, Integer)`.
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

      sig { override.params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        self.class === other && @types.sort_by(&:to_rbi) == other.types.sort_by(&:to_rbi)
      end
    end

    # A type that is intersection of multiple types like `T.all(String, Integer)`.
    class All < Composite
      extend T::Sig

      sig { override.returns(String) }
      def to_rbi
        "T.all(#{@types.map(&:to_rbi).join(", ")})"
      end
    end

    # A type that is union of multiple types like `T.any(String, Integer)`.
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

    # Generics

    # A generic type like `T::Array[String]` or `T::Hash[Symbol, Integer]`.
    class Generic < Type
      extend T::Sig

      sig { returns(String) }
      attr_reader :name

      sig { returns(T::Array[Type]) }
      attr_reader :params

      sig { params(name: String, params: Type).void }
      def initialize(name, *params)
        super()
        @name = name
        @params = T.let(params, T::Array[Type])
      end

      sig { override.params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        Generic === other && @name == other.name && @params == other.params
      end

      sig { override.returns(String) }
      def to_rbi
        "#{@name}[#{@params.map(&:to_rbi).join(", ")}]"
      end
    end

    # A type parameter like `T.type_parameter(:U)`.
    class TypeParameter < Type
      extend T::Sig

      sig { returns(Symbol) }
      attr_reader :name

      sig { params(name: Symbol).void }
      def initialize(name)
        super()
        @name = name
      end

      sig { override.params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        TypeParameter === other && @name == other.name
      end

      sig { override.returns(String) }
      def to_rbi
        "T.type_parameter(#{@name.inspect})"
      end
    end

    # Tuples and shapes

    # A tuple type like `[String, Integer]`.
    class Tuple < Type
      extend T::Sig

      sig { returns(T::Array[Type]) }
      attr_reader :types

      sig { params(types: T::Array[Type]).void }
      def initialize(types)
        super()
        @types = types
      end

      sig { override.params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        Tuple === other && @types == other.types
      end

      sig { override.returns(String) }
      def to_rbi
        "[#{@types.map(&:to_rbi).join(", ")}]"
      end
    end

    # A shape type like `{name: String, age: Integer}`.
    class Shape < Type
      extend T::Sig

      sig { returns(T::Hash[T.any(String, Symbol), Type]) }
      attr_reader :types

      sig { params(types: T::Hash[T.any(String, Symbol), Type]).void }
      def initialize(types)
        super()
        @types = types
      end

      sig { override.params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        Shape === other && @types.sort_by { |t| t.first.to_s } == other.types.sort_by { |t| t.first.to_s }
      end

      sig { override.returns(String) }
      def to_rbi
        if @types.empty?
          "{}"
        else
          "{ " + @types.map { |name, type| "#{name}: #{type.to_rbi}" }.join(", ") + " }"
        end
      end
    end

    # Proc

    # A proc type like `T.proc.void`.
    class Proc < Type
      extend T::Sig

      sig { returns(T::Hash[Symbol, Type]) }
      attr_reader :proc_params

      sig { returns(Type) }
      attr_reader :proc_returns

      sig { returns(T.nilable(Type)) }
      attr_reader :proc_bind

      sig { void }
      def initialize
        super
        @proc_params = T.let({}, T::Hash[Symbol, Type])
        @proc_returns = T.let(Type.void, Type)
        @proc_bind = T.let(nil, T.nilable(Type))
      end

      sig { override.params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        return false unless Proc === other
        return false unless @proc_params == other.proc_params
        return false unless @proc_returns == other.proc_returns
        return false unless @proc_bind == other.proc_bind

        true
      end

      sig { params(params: Type).returns(T.self_type) }
      def params(**params)
        @proc_params = params
        self
      end

      sig { params(type: T.untyped).returns(T.self_type) }
      def returns(type)
        @proc_returns = type
        self
      end

      sig { returns(T.self_type) }
      def void
        @proc_returns = RBI::Type.void
        self
      end

      sig { params(type: T.untyped).returns(T.self_type) }
      def bind(type)
        @proc_bind = type
        self
      end

      sig { override.returns(String) }
      def to_rbi
        rbi = +"T.proc"

        if @proc_bind
          rbi << ".bind(#{@proc_bind})"
        end

        unless @proc_params.empty?
          rbi << ".params("
          rbi << @proc_params.map { |name, type| "#{name}: #{type.to_rbi}" }.join(", ")
          rbi << ")"
        end

        rbi << case @proc_returns
        when Void
          ".void"
        else
          ".returns(#{@proc_returns})"
        end

        rbi
      end
    end

    # Type builder

    class << self
      extend T::Sig

      # Simple

      # Builds a simple type like `String` or `::Foo::Bar`.
      #
      # It raises a `NameError` if the name is not a valid Ruby class identifier.
      sig { params(name: String).returns(Simple) }
      def simple(name)
        # TODO: should we allow creating the instance anyway and move this to a `validate!` method?
        raise NameError, "Invalid type name: `#{name}`" unless valid_identifier?(name)

        Simple.new(name)
      end

      # Literals

      # Builds a type that represents `T.anything`.
      sig { returns(Anything) }
      def anything
        Anything.new
      end

      # Builds a type that represents `T.attached_class`.
      sig { returns(AttachedClass) }
      def attached_class
        AttachedClass.new
      end

      # Builds a type that represents `T::Boolean`.
      sig { returns(Boolean) }
      def boolean
        Boolean.new
      end

      # Builds a type that represents `T.noreturn`.
      sig { returns(NoReturn) }
      def noreturn
        NoReturn.new
      end

      # Builds a type that represents `T.self_type`.
      sig { returns(SelfType) }
      def self_type
        SelfType.new
      end

      # Builds a type that represents `T.untyped`.
      sig { returns(Untyped) }
      def untyped
        Untyped.new
      end

      # Builds a type that represents `void`.
      sig { returns(Void) }
      def void
        Void.new
      end

      # Composites

      # Builds a type that represents the class of another type like `T::Class[Foo]`.
      sig { params(type: Type).returns(Class) }
      def t_class(type)
        Class.new(type)
      end

      # Builds a type that represents the singleton class of another type like `T.class_of(Foo)`.
      sig { params(type: Simple, type_parameter: T.nilable(Type)).returns(ClassOf) }
      def class_of(type, type_parameter = nil)
        ClassOf.new(type, type_parameter)
      end

      # Builds a type that represents a nilable of another type like `T.nilable(String)`.
      #
      # Note that this method transforms types such as `T.nilable(T.untyped)` into `T.untyped`, so
      # it may return something other than a `RBI::Type::Nilable`.
      sig { params(type: Type).returns(Type) }
      def nilable(type)
        # TODO: should we move this logic to a `flatten!`, `normalize!` or `simplify!` method?
        return type if type.is_a?(Untyped)

        if type.nilable?
          type
        else
          Nilable.new(type)
        end
      end

      # Builds a type that represents an intersection of multiple types like `T.all(String, Integer)`.
      #
      # Note that this method transforms types such as `T.all(String, String)` into `String`, so
      # it may return something other than a `All`.
      sig { params(type1: Type, type2: Type, types: Type).returns(Type) }
      def all(type1, type2, *types)
        types = [type1, type2, *types]

        # TODO: should we move this logic to a `flatten!`, `normalize!` or `simplify!` method?
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

      # Builds a type that represents a union of multiple types like `T.any(String, Integer)`.
      #
      # Note that this method transforms types such as `T.any(String, NilClass)` into `T.nilable(String)`, so
      # it may return something other than a `Any`.
      sig { params(type1: Type, type2: Type, types: Type).returns(Type) }
      def any(type1, type2, *types)
        types = [type1, type2, *types]

        # TODO: should we move this logic to a `flatten!`, `normalize!` or `simplify!` method?
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

      # Generics

      # Builds a type that represents a generic type like `T::Array[String]` or `T::Hash[Symbol, Integer]`.
      sig { params(name: String, params: T.any(Type, T::Array[Type])).returns(Generic) }
      def generic(name, *params)
        T.unsafe(Generic).new(name, *params.flatten)
      end

      # Builds a type that represents a type parameter like `T.type_parameter(:U)`.
      sig { params(name: Symbol).returns(TypeParameter) }
      def type_parameter(name)
        TypeParameter.new(name)
      end

      # Tuples and shapes

      # Builds a type that represents a tuple type like `[String, Integer]`.
      sig { params(types: T.any(Type, T::Array[Type])).returns(Tuple) }
      def tuple(*types)
        Tuple.new(types.flatten)
      end

      # Builds a type that represents a shape type like `{name: String, age: Integer}`.
      sig { params(types: T::Hash[T.any(String, Symbol), Type]).returns(Shape) }
      def shape(types = {})
        Shape.new(types)
      end

      # Proc

      # Builds a type that represents a proc type like `T.proc.void`.
      sig { returns(Proc) }
      def proc
        Proc.new
      end

      # We mark the constructor as `protected` because we want to force the use of factories on `Type` to create types
      protected :new

      private

      sig { params(name: String).returns(T::Boolean) }
      def valid_identifier?(name)
        Prism.parse("class self::#{name.delete_prefix("::")}; end").success?
      end
    end

    sig { void }
    def initialize
      @nilable = T.let(false, T::Boolean)
    end

    # Returns a new type that is `nilable` if it is not already.
    #
    # If the type is already nilable, it returns itself.
    # ```ruby
    # type = RBI::Type.simple("String")
    # type.to_rbi # => "String"
    # type.nilable.to_rbi # => "T.nilable(String)"
    # type.nilable.nilable.to_rbi # => "T.nilable(String)"
    # ```
    sig { returns(Type) }
    def nilable
      Type.nilable(self)
    end

    # Returns the non-nilable version of the type.
    # If the type is already non-nilable, it returns itself.
    # If the type is nilable, it returns the inner type.
    #
    # ```ruby
    # type = RBI::Type.nilable(RBI::Type.simple("String"))
    # type.to_rbi # => "T.nilable(String)"
    # type.non_nilable.to_rbi # => "String"
    # type.non_nilable.non_nilable.to_rbi # => "String"
    # ```
    sig { returns(Type) }
    def non_nilable
      # TODO: Should this logic be moved into a builder method?
      case self
      when Nilable
        type
      else
        self
      end
    end

    # Returns whether the type is nilable.
    sig { returns(T::Boolean) }
    def nilable?
      is_a?(Nilable)
    end

    sig { abstract.params(other: BasicObject).returns(T::Boolean) }
    def ==(other); end

    sig { params(other: BasicObject).returns(T::Boolean) }
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
