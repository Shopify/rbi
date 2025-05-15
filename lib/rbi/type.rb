# typed: strict
# frozen_string_literal: true

module RBI
  # The base class for all RBI types.
  # @abstract
  class Type
    # Simple

    # A type that represents a simple class name like `String` or `Foo`.
    #
    # It can also be a qualified name like `::Foo` or `Foo::Bar`.
    class Simple < Type
      #: String
      attr_reader :name

      #: (String name) -> void
      def initialize(name)
        super()
        @name = name
      end

      # @override
      #: (BasicObject other) -> bool
      def ==(other)
        Simple === other && @name == other.name
      end

      # @override
      #: -> String
      def to_rbi
        @name
      end
    end

    # Literals

    # `T.anything`.
    class Anything < Type
      # @override
      #: (BasicObject other) -> bool
      def ==(other)
        Anything === other
      end

      # @override
      #: -> String
      def to_rbi
        "T.anything"
      end
    end

    # `T.attached_class`.
    class AttachedClass < Type
      # @override
      #: (BasicObject other) -> bool
      def ==(other)
        AttachedClass === other
      end

      # @override
      #: -> String
      def to_rbi
        "T.attached_class"
      end
    end

    # `T::Boolean`.
    class Boolean < Type
      # @override
      #: (BasicObject other) -> bool
      def ==(other)
        Boolean === other
      end

      # @override
      #: -> String
      def to_rbi
        "T::Boolean"
      end
    end

    # `T.noreturn`.
    class NoReturn < Type
      # @override
      #: (BasicObject other) -> bool
      def ==(other)
        NoReturn === other
      end

      # @override
      #: -> String
      def to_rbi
        "T.noreturn"
      end
    end

    # `T.self_type`.
    class SelfType < Type
      # @override
      #: (BasicObject other) -> bool
      def ==(other)
        SelfType === other
      end

      # @override
      #: -> String
      def to_rbi
        "T.self_type"
      end
    end

    # `T.untyped`.
    class Untyped < Type
      # @override
      #: (BasicObject other) -> bool
      def ==(other)
        Untyped === other
      end

      # @override
      #: -> String
      def to_rbi
        "T.untyped"
      end
    end

    # `void`.
    class Void < Type
      # @override
      #: (BasicObject other) -> bool
      def ==(other)
        Void === other
      end

      # @override
      #: -> String
      def to_rbi
        "void"
      end
    end

    # Composites

    # The class of another type like `T::Class[Foo]`.
    class Class < Type
      #: Type
      attr_reader :type

      #: (Type type) -> void
      def initialize(type)
        super()
        @type = type
      end

      # @override
      #: (BasicObject other) -> bool
      def ==(other)
        Class === other && @type == other.type
      end

      # @override
      #: -> String
      def to_rbi
        "T::Class[#{@type}]"
      end
    end

    # The singleton class of another type like `T.class_of(Foo)`.
    class ClassOf < Type
      #: Simple
      attr_reader :type

      #: Type?
      attr_reader :type_parameter

      #: (Simple type, ?Type? type_parameter) -> void
      def initialize(type, type_parameter = nil)
        super()
        @type = type
        @type_parameter = type_parameter
      end

      # @override
      #: (BasicObject other) -> bool
      def ==(other)
        ClassOf === other && @type == other.type && @type_parameter == other.type_parameter
      end

      # @override
      #: -> String
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
      #: Type
      attr_reader :type

      #: (Type type) -> void
      def initialize(type)
        super()
        @type = type
      end

      # @override
      #: (BasicObject other) -> bool
      def ==(other)
        Nilable === other && @type == other.type
      end

      # @override
      #: -> String
      def to_rbi
        "T.nilable(#{@type.to_rbi})"
      end
    end

    # A type that is composed of multiple types like `T.all(String, Integer)`.
    # @abstract
    class Composite < Type
      #: Array[Type]
      attr_reader :types

      #: (Array[Type] types) -> void
      def initialize(types)
        super()
        @types = types
      end

      # @override
      #: (BasicObject other) -> bool
      def ==(other)
        self.class === other && @types.sort_by(&:to_rbi) == other.types.sort_by(&:to_rbi)
      end
    end

    # A type that is intersection of multiple types like `T.all(String, Integer)`.
    class All < Composite
      # @override
      #: -> String
      def to_rbi
        "T.all(#{@types.map(&:to_rbi).join(", ")})"
      end
    end

    # A type that is union of multiple types like `T.any(String, Integer)`.
    class Any < Composite
      # @override
      #: -> String
      def to_rbi
        "T.any(#{@types.map(&:to_rbi).join(", ")})"
      end

      #: -> bool
      def nilable?
        @types.any? { |type| type.nilable? || (type.is_a?(Simple) && type.name == "NilClass") }
      end
    end

    # Generics

    # A generic type like `T::Array[String]` or `T::Hash[Symbol, Integer]`.
    class Generic < Type
      #: String
      attr_reader :name

      #: Array[Type]
      attr_reader :params

      #: (String name, *Type params) -> void
      def initialize(name, *params)
        super()
        @name = name
        @params = params #: Array[Type]
      end

      # @override
      #: (BasicObject other) -> bool
      def ==(other)
        Generic === other && @name == other.name && @params == other.params
      end

      # @override
      #: -> String
      def to_rbi
        "#{@name}[#{@params.map(&:to_rbi).join(", ")}]"
      end
    end

    # A type parameter like `T.type_parameter(:U)`.
    class TypeParameter < Type
      #: Symbol
      attr_reader :name

      #: (Symbol name) -> void
      def initialize(name)
        super()
        @name = name
      end

      # @override
      #: (BasicObject other) -> bool
      def ==(other)
        TypeParameter === other && @name == other.name
      end

      # @override
      #: -> String
      def to_rbi
        "T.type_parameter(#{@name.inspect})"
      end
    end

    # Tuples and shapes

    # A tuple type like `[String, Integer]`.
    class Tuple < Type
      #: Array[Type]
      attr_reader :types

      #: (Array[Type] types) -> void
      def initialize(types)
        super()
        @types = types
      end

      # @override
      #: (BasicObject other) -> bool
      def ==(other)
        Tuple === other && @types == other.types
      end

      # @override
      #: -> String
      def to_rbi
        "[#{@types.map(&:to_rbi).join(", ")}]"
      end
    end

    # A shape type like `{name: String, age: Integer}`.
    class Shape < Type
      #: Hash[(String | Symbol), Type]
      attr_reader :types

      #: (Hash[(String | Symbol), Type] types) -> void
      def initialize(types)
        super()
        @types = types
      end

      # @override
      #: (BasicObject other) -> bool
      def ==(other)
        Shape === other && @types.sort_by { |t| t.first.to_s } == other.types.sort_by { |t| t.first.to_s }
      end

      # @override
      #: -> String
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
      #: Hash[Symbol, Type]
      attr_reader :proc_params

      #: Type
      attr_reader :proc_returns

      #: Type?
      attr_reader :proc_bind

      #: -> void
      def initialize
        super
        @proc_params = {} #: Hash[Symbol, Type]
        @proc_returns = Type.void #: Type
        @proc_bind = nil #: Type?
      end

      # @override
      #: (BasicObject other) -> bool
      def ==(other)
        return false unless Proc === other
        return false unless @proc_params == other.proc_params
        return false unless @proc_returns == other.proc_returns
        return false unless @proc_bind == other.proc_bind

        true
      end

      #: (**Type params) -> self
      def params(**params)
        @proc_params = params
        self
      end

      #: (untyped type) -> self
      def returns(type)
        @proc_returns = type
        self
      end

      #: -> self
      def void
        @proc_returns = RBI::Type.void
        self
      end

      #: (untyped type) -> self
      def bind(type)
        @proc_bind = type
        self
      end

      # @override
      #: -> String
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
      # Simple

      # Builds a simple type like `String` or `::Foo::Bar`.
      #
      # It raises a `NameError` if the name is not a valid Ruby class identifier.
      #: (String name) -> Simple
      def simple(name)
        # TODO: should we allow creating the instance anyway and move this to a `validate!` method?
        raise NameError, "Invalid type name: `#{name}`" unless valid_identifier?(name)

        Simple.new(name)
      end

      # Literals

      # Builds a type that represents `T.anything`.
      #: -> Anything
      def anything
        Anything.new
      end

      # Builds a type that represents `T.attached_class`.
      #: -> AttachedClass
      def attached_class
        AttachedClass.new
      end

      # Builds a type that represents `T::Boolean`.
      #: -> Boolean
      def boolean
        Boolean.new
      end

      # Builds a type that represents `T.noreturn`.
      #: -> NoReturn
      def noreturn
        NoReturn.new
      end

      # Builds a type that represents `T.self_type`.
      #: -> SelfType
      def self_type
        SelfType.new
      end

      # Builds a type that represents `T.untyped`.
      #: -> Untyped
      def untyped
        Untyped.new
      end

      # Builds a type that represents `void`.
      #: -> Void
      def void
        Void.new
      end

      # Composites

      # Builds a type that represents the class of another type like `T::Class[Foo]`.
      #: (Type type) -> Class
      def t_class(type)
        Class.new(type)
      end

      # Builds a type that represents the singleton class of another type like `T.class_of(Foo)`.
      #: (Simple type, ?Type? type_parameter) -> ClassOf
      def class_of(type, type_parameter = nil)
        ClassOf.new(type, type_parameter)
      end

      # Builds a type that represents a nilable of another type like `T.nilable(String)`.
      #
      # Note that this method transforms types such as `T.nilable(T.untyped)` into `T.untyped`, so
      # it may return something other than a `RBI::Type::Nilable`.
      #: (Type type) -> Type
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
      #: (Type type1, Type type2, *Type types) -> Type
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
          flattened.first #: as !nil
        else
          raise ArgumentError, "RBI::Type.all should have at least 2 types supplied" if flattened.size < 2

          All.new(flattened)
        end
      end

      # Builds a type that represents a union of multiple types like `T.any(String, Integer)`.
      #
      # Note that this method transforms types such as `T.any(String, NilClass)` into `T.nilable(String)`, so
      # it may return something other than a `Any`.
      #: (Type type1, Type type2, *Type types) -> Type
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

        is_nilable = false #: bool

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
          types.first #: as !nil
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
      #: (String name, *(Type | Array[Type]) params) -> Generic
      def generic(name, *params)
        Generic.new(name, *params.flatten)
      end

      # Builds a type that represents a type parameter like `T.type_parameter(:U)`.
      #: (Symbol name) -> TypeParameter
      def type_parameter(name)
        TypeParameter.new(name)
      end

      # Tuples and shapes

      # Builds a type that represents a tuple type like `[String, Integer]`.
      #: (*(Type | Array[Type]) types) -> Tuple
      def tuple(*types)
        Tuple.new(types.flatten)
      end

      # Builds a type that represents a shape type like `{name: String, age: Integer}`.
      #: (?Hash[(String | Symbol), Type] types) -> Shape
      def shape(types = {})
        Shape.new(types)
      end

      # Proc

      # Builds a type that represents a proc type like `T.proc.void`.
      #: -> Proc
      def proc
        Proc.new
      end

      # We mark the constructor as `protected` because we want to force the use of factories on `Type` to create types
      protected :new

      private

      #: (String name) -> bool
      def valid_identifier?(name)
        Prism.parse("class self::#{name.delete_prefix("::")}; end").success?
      end
    end

    #: -> void
    def initialize
      @nilable = false #: bool
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
    #: -> Type
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
    #: -> Type
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
    #: -> bool
    def nilable?
      is_a?(Nilable)
    end

    # @abstract
    #: (BasicObject) -> bool
    def ==(other); end

    #: (BasicObject other) -> bool
    def eql?(other)
      self == other
    end

    # @override
    #: -> Integer
    def hash
      to_rbi.hash
    end

    # @abstract
    #: -> String
    def to_rbi; end

    # @override
    #: -> String
    def to_s
      to_rbi
    end
  end
end
