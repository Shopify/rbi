# typed: strict
# frozen_string_literal: true

module RBI
  module RBS
    class MethodTypeTranslator
      class Error < RBI::Error; end

      class << self
        sig { params(method: Method, type: ::RBS::MethodType).returns(Sig) }
        def translate(method, type); end
      end

      sig { returns(Sig) }
      attr_reader :result

      sig { params(method: Method).void }
      def initialize(method); end

      sig { params(type: ::RBS::MethodType).void }
      def visit(type); end

      private

      sig { params(type: ::RBS::Types::Block).void }
      def visit_block_type(type); end

      sig { params(type: ::RBS::Types::Function).void }
      def visit_function_type(type); end

      sig { params(param: ::RBS::Types::Function::Param, index: Integer).returns(SigParam) }
      def translate_function_param(param, index); end

      sig { params(type: T.untyped).returns(Type) }
      def translate_type(type); end
    end
  end
end
