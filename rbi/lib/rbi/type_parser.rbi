# typed: strict
# frozen_string_literal: true

# `Foo`

# `T::Boolean` or `::T::Boolean`

# `::Foo` or `::Foo::Bar`

# `void`

# `Foo[Bar]` or `Foo[Bar, Baz]`

# `T::Class[Foo]` or `::T::Class[Foo]`

# `::Foo[Bar]` or `::Foo[Bar, Baz]`

# `T.class_of(Foo)[Bar]`

# `something[]`

# `T.proc`

# `Foo.nilable` or anything called on a constant that is not `::T`

# `T.nilable(Foo)`

# `T.anything`

# `T.untyped`

# `T.noreturn`

# `T.self_type`

# `T.attached_class`

# `T.class_of(Foo)`

# `T.all(Foo, Bar)`

# `T.any(Foo, Bar)`

# `T.type_parameter(:T)`

# `T.something`

# remove `T.`

module RBI
  class Type
    class Error < RBI::Error; end

    class << self
      sig { params(string: String).returns(Type) }
      def parse_string(string); end

      sig { params(node: Prism::Node).returns(Type) }
      def parse_node(node); end

      private

      sig { params(node: T.any(Prism::ConstantReadNode, Prism::ConstantPathNode)).returns(Type) }
      def parse_constant(node); end

      sig { params(node: Prism::CallNode).returns(Type) }
      def parse_call(node); end

      sig { params(node: Prism::ArrayNode).returns(Type) }
      def parse_tuple(node); end

      sig { params(node: T.any(Prism::HashNode, Prism::KeywordHashNode)).returns(Type) }
      def parse_shape(node); end

      sig { params(node: Prism::CallNode).returns(Type) }
      def parse_proc(node); end

      sig { params(node: Prism::CallNode, count: Integer).returns(Array[Prism::Node]) }
      def check_arguments_exactly!(node, count); end

      sig { params(node: Prism::CallNode, count: Integer).returns(Array[Prism::Node]) }
      def check_arguments_at_least!(node, count); end

      sig { params(node: Prism::CallNode).returns(Array[Prism::Node]) }
      def call_chain(node); end

      sig { params(node: T.nilable(Prism::Node)).returns(T::Boolean) }
      def t?(node); end

      sig { params(node: T.nilable(Prism::Node)).returns(T::Boolean) }
      def t_boolean?(node); end

      sig { params(node: Prism::ConstantPathNode).returns(T::Boolean) }
      def t_class?(node); end

      sig { params(node: T.nilable(Prism::Node)).returns(T::Boolean) }
      def t_class_of?(node); end

      sig { params(node: Prism::CallNode).returns(T::Boolean) }
      def t_proc?(node); end
    end
  end
end
