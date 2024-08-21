# typed: strict
# frozen_string_literal: true

module RBI
  module RBS
    class TypeConverter
      extend T::Sig

      sig { params(type_params: T::Array[::RBS::AST::TypeParam]).void }
      def initialize(type_params = [])
        # @converter = converter
        @type_params = type_params
        @type_param_names = T.let(type_params.map(&:to_s), T::Array[String])
      end

      sig { params(type_params: T::Array[::RBS::AST::TypeParam]).returns(T.self_type) }
      def with_type_params(type_params)
        self.class.new(type_params)
      end

      sig { returns(T::Array[::RBS::AST::TypeParam]) }
      attr_reader :type_params

      sig { params(type: T.untyped).returns(T::Types::Base) }
      def convert(type)
        # @converter.push_foreign_name(type.name) if type.respond_to?(:name)

        case type
        when ::RBS::Types::Alias
          string_holder(type.name.to_s)
        when ::RBS::Types::Bases::Any
          T.untyped
        when ::RBS::Types::Bases::Bool
          T::Boolean
        when ::RBS::Types::Bases::Bottom
          T.untyped
        when ::RBS::Types::Bases::Instance
          T::Types::AttachedClassType::Private.const_get(:INSTANCE) # rubocop:disable Sorbet/ConstantsFromStrings
        when ::RBS::Types::Bases::Nil
          T::Utils.coerce(NilClass)
        when ::RBS::Types::Bases::Self
          T.self_type
        when ::RBS::Types::Bases::Top
          T::Utils.coerce(BasicObject)
        when ::RBS::Types::Bases::Void
          T::Private::Types::Void.new
        when ::RBS::Types::Bases::Class
          # unhandled
        when ::RBS::Types::ClassInstance
          name = type.name
          name = name.relative!.with_prefix(Namespace("::T")) if should_prefix_with_t?(type)
          name = append_type_variables(name.to_s, type.args)

          string_holder(name)
        when ::RBS::Types::Interface
          name = type.name
          name = "T::Enumerable" if name.to_s == "_Each"
          name = append_type_variables(name.to_s, type.args)

          string_holder(name)
        when ::RBS::Types::Intersection
          types = T.unsafe(type.types.map { |type| convert(type) })
          T.all(*types)
        when ::RBS::Types::Literal
          T.untyped
        when ::RBS::Types::Optional
          type = convert(type.type)
          if T::Types::Untyped === type
            type
          else
            T.nilable(T.unsafe(type))
          end
        when ::RBS::Types::Proc
          params = convert_parameters(type.type, type.block).to_h { |p| [p.name, p.type] }
          T::Types::Proc.new(params, convert(type.type.return_type))
        when ::RBS::Types::Record
          T::Utils.coerce(type.fields.to_h { |key, type| [key, convert(type)] })
        when ::RBS::Types::Tuple
          T::Utils.coerce(type.types.map { |type| convert(type) })
        when ::RBS::Types::Union
          types = T.unsafe(type.types.map { |type| convert(type) })
          union_type = T.any(*types)

          if union_type.to_s == "T.nilable(T.untyped)"
            T.untyped
          else
            union_type
          end
        when ::RBS::Types::Variable
          if @type_param_names.include?(type.name.to_s)
            T::Types::TypeParameter.new(type.name.to_sym)
          else
            string_holder(type.name.to_s)
          end
        when ::RBS::Types::ClassSingleton
          # Don't know how to handle this...
          T.untyped
        when ::RBS::Types::Block
          params = convert_parameters(type.type, nil).to_h { |p| [p.name, p.type] }
          block = T::Types::Proc.new(params, convert(type.type.return_type))
          block = T.nilable(T.unsafe(block)) unless type.required
          block
        else
          raise "Unknown RBS type: <#{type.class}>"
        end
      end

      sig do
        params(
          type: ::RBS::Types::Function,
          block: T.nilable(::RBS::Types::Block),
        ).returns(T::Array[ParameterResult])
      end
      def convert_parameters(type, block)
        parameters = [
          *type.required_positionals.map { |param| [:req, param.name, param] },
          *type.optional_positionals.map { |param| [:opt, param.name, param] },
          *Array(type.rest_positionals).map { |param| [:rest, param.name, param] },
          *type.trailing_positionals.map { |param| [:opt, param.name, param] },
          *type.required_keywords.map { |name, param| [:keyreq, name, param] },
          *type.optional_keywords.map { |name, param| [:key, name, param] },
          *Array(type.rest_keywords).map { |param| [:keyrest, param.name, param] },
          *Array(block).map { |param| [:block, :blk, param] },
        ]

        parameters.map.with_index do |(kind, name, param), index|
          create_param_result(kind, name, param, index)
        end
      end

      sig { params(type: T.untyped).returns(String) }
      def to_string(type)
        type = convert(type) unless T::Types::Base === type
        sanitize_signature_types(type.to_s)
      end

      sig { params(visibility: Symbol).returns(RBI::Visibility) }
      def visibility(visibility)
        case visibility
        when :public
          RBI::Public.new
        when :private
          RBI::Private.new
        else
          raise "Unknown visibility: `#{visibility}`"
        end
      end

      private

      class ParameterResult < T::Struct
        const :kind, Symbol
        const :name, String
        const :type, T::Types::Base
      end

      sig do
        params(
          kind: Symbol,
          name: T.nilable(Symbol),
          param: T.any(::RBS::Types::Function::Param, ::RBS::Types::Block),
          index: Integer,
        ).returns(ParameterResult)
      end
      def create_param_result(kind, name, param, index)
        name = nil if [:module, :class, :end, :if, :unless].include?(name)
        name = (name || "_arg#{index}").to_s

        param_type = case param
        when ::RBS::Types::Block
          param
        else
          param.type
        end

        ParameterResult.new(kind: kind, name: name, type: convert(param_type))
      end

      T_GENERIC_TYPES = T.let(
        [
          "Hash",
          "Array",
          "Set",
          "Enumerable",
          "Enumerable::Lazy",
          "Enumerator",
          "Range",
        ].to_set.freeze,
        T::Set[String],
      )

      sig { params(type: ::RBS::Types::ClassInstance).returns(T::Boolean) }
      def should_prefix_with_t?(type)
        name = type.name

        name.class? &&
          name.namespace.empty? &&
          T_GENERIC_TYPES.include?(name.relative!.to_s) &&
          !type.args.empty?
      end

      sig { params(name: String, type_args: T::Array[T.untyped]).returns(String) }
      def append_type_variables(name, type_args)
        type_variables = type_args.map { |arg| to_string(arg) }.join(", ")

        if type_variables.empty?
          name
        else
          "#{name}[#{type_variables}]"
        end
      end

      sig { params(type_name: String).returns(T::Private::Types::StringHolder) }
      def string_holder(type_name)
        T::Private::Types::StringHolder.new(type_name)
      end

      sig { params(sig_string: String).returns(String) }
      def sanitize_signature_types(sig_string)
        sig_string
          .gsub(".returns(<VOID>)", ".void")
          .gsub("<VOID>", "void")
          .gsub("<NOT-TYPED>", "T.untyped")
          .gsub(".params()", "")
      end
    end
  end
end
