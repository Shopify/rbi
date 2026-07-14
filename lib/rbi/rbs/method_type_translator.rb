# typed: strict
# frozen_string_literal: true

module RBI
  module RBS
    class MethodTypeTranslator
      class Error < RBI::Error; end

      class << self
        #: (Method, ::RBS::MethodType) -> Sig
        def translate(method, type)
          translator = new(method)
          translator.visit(type)
          translator.result
        end
      end

      class Options
        #: bool
        attr_reader :erase_generic_types

        #: (?erase_generic_types: bool) -> void
        def initialize(erase_generic_types: false)
          @erase_generic_types = erase_generic_types
        end

        @default = new.freeze #: Options
        class << self
          #: Options
          attr_reader :default
        end
      end

      #: Sig
      attr_reader :result

      #: (Method, ?options: Options) -> void
      def initialize(method, options: Options.default)
        @method = method
        @options = options

        @result = Sig.new #: Sig
        @type_translator = TypeTranslator.new(options: @options) #: TypeTranslator
      end

      #: (::RBS::MethodType) -> void
      def visit(type)
        unless @options.erase_generic_types
          type.type_params.each do |param|
            result.type_params << param.name
          end
        end

        visit_function_type(type.type)

        block = type.block
        visit_block_type(block) if block
      end

      private

      #: (::RBS::Types::Block) -> void
      def visit_block_type(type)
        block_param = @method.params.grep(RBI::BlockParam).first
        raise Error, "No block param found" unless block_param

        block_name = block_param.name.empty? ? "block" : block_param.name
        block_type = translate_type(type.type) #: as RBI::Type::Proc

        bind = type.self_type
        block_type.bind(translate_type(bind)) if bind
        block_type = block_type.nilable unless type.required

        @result.params << SigParam.new(block_name, block_type)
      end

      #: (::RBS::Types::Function) -> void
      def visit_function_type(type)
        index = 0

        type.required_positionals.each do |param|
          result.params << translate_function_param(param, index)
          index += 1
        end

        type.optional_positionals.each do |param|
          result.params << translate_function_param(param, index)
          index += 1
        end

        rest_positional = type.rest_positionals
        if rest_positional
          result.params << translate_function_param(rest_positional, index)
          index += 1
        end

        type.trailing_positionals.each do |param|
          result.params << translate_function_param(param, index)
          index += 1
        end

        type.required_keywords.each do |name, param|
          result.params << SigParam.new(name.to_s, translate_type(param.type))
          index += 1
        end

        type.optional_keywords.each do |name, param|
          result.params << SigParam.new(name.to_s, translate_type(param.type))
          index += 1
        end

        rest_keyword = type.rest_keywords
        if rest_keyword
          result.params << translate_function_param(rest_keyword, index)
        end

        result.return_type = translate_type(type.return_type)
      end

      #: (::RBS::Types::Function::Param, Integer) -> SigParam
      def translate_function_param(param, index)
        param_type = translate_type(param.type)
        param_name = param.name&.to_s

        unless param_name
          method_param_name = @method.params[index]
          raise Error, "No method param name found for parameter ##{index}" unless method_param_name

          param_name = method_param_name.name
        end

        SigParam.new(param_name, param_type)
      end

      #: (untyped) -> Type
      def translate_type(type)
        @type_translator.translate(type)
      end
    end
  end
end
