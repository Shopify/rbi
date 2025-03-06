# typed: strict
# frozen_string_literal: true

# Simple

# Literals

# Composites

# Generics

# Tuples and shapes

# Proc

# Type builder

# Simple

# TODO: should we allow creating the instance anyway and move this to a `validate!` method?

# Literals

# Composites

# TODO: should we move this logic to a `flatten!`, `normalize!` or `simplify!` method?

# TODO: should we move this logic to a `flatten!`, `normalize!` or `simplify!` method?

# TODO: should we move this logic to a `flatten!`, `normalize!` or `simplify!` method?

# Generics

# Tuples and shapes

# Proc

# TODO: Should this logic be moved into a builder method?

module RBI
  # The base class for all RBI types.
  class Type
    extend T::Sig
    extend T::Helpers
    abstract!

    # A type that represents a simple class name like `String` or `Foo`.
    #
    # It can also be a qualified name like `::Foo` or `Foo::Bar`.
    class Simple < Type
      sig { returns(String) }
      attr_reader :name

      sig { params(name: String).void }
      def initialize(name); end

      # @override
      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other); end

      # @override
      sig { returns(String) }
      def to_rbi; end
    end

    # `T.anything`.
    class Anything < Type
      # @override
      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other); end

      # @override
      sig { returns(String) }
      def to_rbi; end
    end

    # `T.attached_class`.
    class AttachedClass < Type
      # @override
      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other); end

      # @override
      sig { returns(String) }
      def to_rbi; end
    end

    # `T::Boolean`.
    class Boolean < Type
      # @override
      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other); end

      # @override
      sig { returns(String) }
      def to_rbi; end
    end

    # `T.noreturn`.
    class NoReturn < Type
      # @override
      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other); end

      # @override
      sig { returns(String) }
      def to_rbi; end
    end

    # `T.self_type`.
    class SelfType < Type
      # @override
      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other); end

      # @override
      sig { returns(String) }
      def to_rbi; end
    end

    # `T.untyped`.
    class Untyped < Type
      # @override
      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other); end

      # @override
      sig { returns(String) }
      def to_rbi; end
    end

    # `void`.
    class Void < Type
      # @override
      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other); end

      # @override
      sig { returns(String) }
      def to_rbi; end
    end

    # The class of another type like `T::Class[Foo]`.
    class Class < Type
      sig { returns(Type) }
      attr_reader :type

      sig { params(type: Type).void }
      def initialize(type); end

      # @override
      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other); end

      # @override
      sig { returns(String) }
      def to_rbi; end
    end

    # The singleton class of another type like `T.class_of(Foo)`.
    class ClassOf < Type
      sig { returns(Simple) }
      attr_reader :type

      sig { returns(T.nilable(Type)) }
      attr_reader :type_parameter

      sig { params(type: Simple, type_parameter: T.nilable(Type)).void }
      def initialize(type, type_parameter = nil); end

      # @override
      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other); end

      # @override
      sig { returns(String) }
      def to_rbi; end
    end

    # A type that can be `nil` like `T.nilable(String)`.
    class Nilable < Type
      sig { returns(Type) }
      attr_reader :type

      sig { params(type: Type).void }
      def initialize(type); end

      # @override
      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other); end

      # @override
      sig { returns(String) }
      def to_rbi; end
    end

    # A type that is composed of multiple types like `T.all(String, Integer)`.
    class Composite < Type
      extend T::Helpers
      abstract!

      sig { returns(Array[Type]) }
      attr_reader :types

      sig { params(types: Array[Type]).void }
      def initialize(types); end

      # @override
      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other); end
    end

    # A type that is intersection of multiple types like `T.all(String, Integer)`.
    class All < Composite
      # @override
      sig { returns(String) }
      def to_rbi; end
    end

    # A type that is union of multiple types like `T.any(String, Integer)`.
    class Any < Composite
      # @override
      sig { returns(String) }
      def to_rbi; end

      sig { returns(T::Boolean) }
      def nilable?; end
    end

    # A generic type like `T::Array[String]` or `T::Hash[Symbol, Integer]`.
    class Generic < Type
      sig { returns(String) }
      attr_reader :name

      sig { returns(Array[Type]) }
      attr_reader :params

      sig { params(name: String, params: Type).void }
      def initialize(name, *params); end

      # @override
      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other); end

      # @override
      sig { returns(String) }
      def to_rbi; end
    end

    # A type parameter like `T.type_parameter(:U)`.
    class TypeParameter < Type
      sig { returns(Symbol) }
      attr_reader :name

      sig { params(name: Symbol).void }
      def initialize(name); end

      # @override
      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other); end

      # @override
      sig { returns(String) }
      def to_rbi; end
    end

    # A tuple type like `[String, Integer]`.
    class Tuple < Type
      sig { returns(Array[Type]) }
      attr_reader :types

      sig { params(types: Array[Type]).void }
      def initialize(types); end

      # @override
      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other); end

      # @override
      sig { returns(String) }
      def to_rbi; end
    end

    # A shape type like `{name: String, age: Integer}`.
    class Shape < Type
      sig { returns(Hash[T.any(String, Symbol), Type]) }
      attr_reader :types

      sig { params(types: Hash[T.any(String, Symbol), Type]).void }
      def initialize(types); end

      # @override
      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other); end

      # @override
      sig { returns(String) }
      def to_rbi; end
    end

    # A proc type like `T.proc.void`.
    class Proc < Type
      sig { returns(Hash[Symbol, Type]) }
      attr_reader :proc_params

      sig { returns(Type) }
      attr_reader :proc_returns

      sig { returns(T.nilable(Type)) }
      attr_reader :proc_bind

      sig { void }
      def initialize; end

      # @override
      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other); end

      sig { params(params: Type).returns(T.self_type) }
      def params(**params); end

      sig { params(type: T.untyped).returns(T.self_type) }
      def returns(type); end

      sig { returns(T.self_type) }
      def void; end

      sig { params(type: T.untyped).returns(T.self_type) }
      def bind(type); end

      # @override
      sig { returns(String) }
      def to_rbi; end
    end

    class << self
      # Builds a simple type like `String` or `::Foo::Bar`.
      #
      # It raises a `NameError` if the name is not a valid Ruby class identifier.
      sig { params(name: String).returns(Simple) }
      def simple(name); end

      # Builds a type that represents `T.anything`.
      sig { returns(Anything) }
      def anything; end

      # Builds a type that represents `T.attached_class`.
      sig { returns(AttachedClass) }
      def attached_class; end

      # Builds a type that represents `T::Boolean`.
      sig { returns(Boolean) }
      def boolean; end

      # Builds a type that represents `T.noreturn`.
      sig { returns(NoReturn) }
      def noreturn; end

      # Builds a type that represents `T.self_type`.
      sig { returns(SelfType) }
      def self_type; end

      # Builds a type that represents `T.untyped`.
      sig { returns(Untyped) }
      def untyped; end

      # Builds a type that represents `void`.
      sig { returns(Void) }
      def void; end

      # Builds a type that represents the class of another type like `T::Class[Foo]`.
      sig { params(type: Type).returns(Class) }
      def t_class(type); end

      # Builds a type that represents the singleton class of another type like `T.class_of(Foo)`.
      sig { params(type: Simple, type_parameter: T.nilable(Type)).returns(ClassOf) }
      def class_of(type, type_parameter = nil); end

      # Builds a type that represents a nilable of another type like `T.nilable(String)`.
      #
      # Note that this method transforms types such as `T.nilable(T.untyped)` into `T.untyped`, so
      # it may return something other than a `RBI::Type::Nilable`.
      sig { params(type: Type).returns(Type) }
      def nilable(type); end

      # Builds a type that represents an intersection of multiple types like `T.all(String, Integer)`.
      #
      # Note that this method transforms types such as `T.all(String, String)` into `String`, so
      # it may return something other than a `All`.
      sig { params(type1: Type, type2: Type, types: Type).returns(Type) }
      def all(type1, type2, *types); end

      # Builds a type that represents a union of multiple types like `T.any(String, Integer)`.
      #
      # Note that this method transforms types such as `T.any(String, NilClass)` into `T.nilable(String)`, so
      # it may return something other than a `Any`.
      sig { params(type1: Type, type2: Type, types: Type).returns(Type) }
      def any(type1, type2, *types); end

      # Builds a type that represents a generic type like `T::Array[String]` or `T::Hash[Symbol, Integer]`.
      sig { params(name: String, params: T.any(Type, Array[Type])).returns(Generic) }
      def generic(name, *params); end

      # Builds a type that represents a type parameter like `T.type_parameter(:U)`.
      sig { params(name: Symbol).returns(TypeParameter) }
      def type_parameter(name); end

      # Builds a type that represents a tuple type like `[String, Integer]`.
      sig { params(types: T.any(Type, Array[Type])).returns(Tuple) }
      def tuple(*types); end

      # Builds a type that represents a shape type like `{name: String, age: Integer}`.
      sig { params(types: Hash[T.any(String, Symbol), Type]).returns(Shape) }
      def shape(types = {}); end

      # Builds a type that represents a proc type like `T.proc.void`.
      sig { returns(Proc) }
      protected def proc; end

      private

      sig { params(name: String).returns(T::Boolean) }
      def valid_identifier?(name); end
    end

    sig { void }
    def initialize; end

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
    def nilable; end

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
    def non_nilable; end

    # Returns whether the type is nilable.
    sig { returns(T::Boolean) }
    def nilable?; end

    sig { abstract.params(other: BasicObject).returns(T::Boolean) }
    def ==(other); end

    sig { params(other: BasicObject).returns(T::Boolean) }
    def eql?(other); end

    # @override
    sig { returns(Integer) }
    def hash; end

    sig { abstract.returns(String) }
    def to_rbi; end

    # @override
    sig { returns(String) }
    def to_s; end
  end
end
