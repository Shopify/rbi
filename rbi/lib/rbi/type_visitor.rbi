# typed: strict
# frozen_string_literal: true

module RBI
  class Type
    class Visitor
      class Error < RBI::Error; end

      sig { params(node: Type).void }
      def visit(node); end

      private

      sig { params(type: Type::All).void }
      def visit_all(type); end

      sig { params(type: Type::Any).void }
      def visit_any(type); end

      sig { params(type: Type::Anything).void }
      def visit_anything(type); end

      sig { params(type: Type::AttachedClass).void }
      def visit_attached_class(type); end

      sig { params(type: Type::Boolean).void }
      def visit_boolean(type); end

      sig { params(type: Type::Class).void }
      def visit_class(type); end

      sig { params(type: Type::ClassOf).void }
      def visit_class_of(type); end

      sig { params(type: Type::Generic).void }
      def visit_generic(type); end

      sig { params(type: Type::Nilable).void }
      def visit_nilable(type); end

      sig { params(type: Type::Simple).void }
      def visit_simple(type); end

      sig { params(type: Type::NoReturn).void }
      def visit_no_return(type); end

      sig { params(type: Type::Proc).void }
      def visit_proc(type); end

      sig { params(type: Type::SelfType).void }
      def visit_self_type(type); end

      sig { params(type: Type::Void).void }
      def visit_void(type); end

      sig { params(type: Type::Shape).void }
      def visit_shape(type); end

      sig { params(type: Type::Tuple).void }
      def visit_tuple(type); end

      sig { params(type: Type::TypeParameter).void }
      def visit_type_parameter(type); end

      sig { params(type: Type::Untyped).void }
      def visit_untyped(type); end
    end
  end
end
