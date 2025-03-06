# typed: strict
# frozen_string_literal: true

# TODO: unsupported yet

# TODO: unsupported yet

# TODO: unsupported yet

# TODO: unsupported yet

module RBI
  module RBS
    class TypeTranslator
      class << self
        NodeType = T.type_alias do
          T.any(
            ::RBS::Types::Alias,
            ::RBS::Types::Bases::Any,
            ::RBS::Types::Bases::Bool,
            ::RBS::Types::Bases::Bottom,
            ::RBS::Types::Bases::Class,
            ::RBS::Types::Bases::Instance,
            ::RBS::Types::Bases::Nil,
            ::RBS::Types::Bases::Self,
            ::RBS::Types::Bases::Top,
            ::RBS::Types::Bases::Void,
            ::RBS::Types::ClassSingleton,
            ::RBS::Types::ClassInstance,
            ::RBS::Types::Function,
            ::RBS::Types::Interface,
            ::RBS::Types::Intersection,
            ::RBS::Types::Literal,
            ::RBS::Types::Optional,
            ::RBS::Types::Proc,
            ::RBS::Types::Record,
            ::RBS::Types::Tuple,
            ::RBS::Types::Union,
            ::RBS::Types::UntypedFunction,
            ::RBS::Types::Variable,
          )
        end

        sig { params(type: NodeType).returns(Type) }
        def translate(type); end

        private

        sig { params(type: ::RBS::Types::ClassInstance).returns(Type) }
        def translate_class_instance(type); end

        sig { params(type: ::RBS::Types::Function).returns(Type) }
        def translate_function(type); end

        sig { params(type_name: String).returns(String) }
        def translate_t_generic_type(type_name); end
      end
    end
  end
end
