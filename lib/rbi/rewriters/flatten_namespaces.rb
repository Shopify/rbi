# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    # Flattens nested scopes to fully-qualified names.modulemodulemodulemodulemodulemodule
    #
    # Example:
    # ~~~rb
    # class X; end
    # module M; end
    # module A
    #   class Y; end
    #   module N; end
    #   class B < X; end
    #
    #   class C < Y
    #     include M
    #     extend N
    #     extend T::Sig
    #
    #     sig { params(c: C).returns(B) }
    #     def m(c); end
    #   end
    # end
    # ~~~
    #
    # will be transformed into:
    #
    # ~~~rb
    # class X; end
    # module M; end
    # module A; end
    # class A::Y; end
    # module A::N; end
    # class A::B < X; end
    #
    # class A::C < A::Y
    #   include M
    #   extend A::N
    #   extend T::Sig
    #
    #   sig { params(c: A::C).returns(A::B) }
    #   def m(c); end
    # end
    # ~~~
    class FlattenNamespaces < Visitor
      DEBUG = false

      #: (Tree root) -> void
      def initialize(root)
        super()

        @scope_stack = [root] #: Array[Tree]
      end

      #: -> Tree
      def root
        @scope_stack.first || raise("No root found")
      end

      # @override
      #: (Node? node) -> void
      def visit(node)
        return unless node

        debug { "visiting #{node}" }

        case node
        when Module, Class, Struct
          # Depth-first recursion so children become fully qualified first
          @scope_stack << node
          visit_all(node.nodes.dup)
          @scope_stack.pop

          if node.parent_tree != root
            debug { "hoisting #{node}" }
            if node.is_a?(Class) && node.superclass_name
              node.superclass_name = fully_qualified_name_for(
                local_name: node.superclass_name,
              )
            end
            node.name = node.fully_qualified_name.sub(/^::/, "")
            node.detach
            root << node
          end
        when Tree
          visit_all(node.nodes)
        when Mixin
          node.names = node.names.map do |name|
            fully_qualified_name_for(
              local_name: name,
              # Don't include the current class scope:
              in_scope_stack: @scope_stack[...-1],
            )
          end
        when Attr, Method
          node.sigs.each do |sig|
            sig.params.each do |param|
              param.type = fully_qualify_type(param.type)
            end
            sig.return_type = fully_qualify_type(sig.return_type)
          end
        end
      end

      private

      #: (local_name: String, ?in_scope_stack: Array[Tree]) -> String
      def fully_qualified_name_for(local_name:, in_scope_stack: @scope_stack)
        if in_scope_stack.last == root || local_name.start_with?("::")
          return local_name.sub(/^::/, "")
        end

        # Look up the leftmost name component in the scope chain.
        leftmost_name = local_name.split("::").first
        scope = in_scope_stack.reverse_each.find do |scope|
          scope.nodes.find { _1.respond_to?(:name) && _1.name == leftmost_name }
        end
        if scope == root
          debug { "fully_qualified_name_for(#{local_name.inspect}) found in root" }
          return local_name
        end

        if scope
          debug { "fully_qualified_name_for(#{local_name.inspect}) found in #{scope}" }
          return scope.fully_qualified_name.sub(/^::/, "") + "::" + local_name
        end

        # At this point the referent may have been hoisted to the toplevel, so look for fully qualified names based on the current scope.
        scope_components = in_scope_stack.last.fully_qualified_name.split("::")
        while scope_components.any?
          fqn = scope_components.join("::") + "::" + local_name
          debug { "fully_qualified_name_for(#{local_name.inspect}) trying #{fqn} in root" }
          if root.nodes.any? { _1.respond_to?(:fully_qualified_name) && _1.fully_qualified_name == fqn }
            debug { "fully_qualified_name_for(#{local_name.inspect}) found in root" }
            return fqn.sub(/^::/, "")
          end

          scope_components.pop
        end

        debug { "fully_qualified_name_for(#{local_name.inspect}) not found" }
        # Finally, assume this is a global name defined elsewhere.
        local_name
      end

      #: ((Type | String) type) -> Type
      def fully_qualify_type(type)
        debug { "fully_qualify_type(#{type.inspect})" }
        case type
        when "void"
          type
        when String
          Type.simple(fully_qualified_name_for(local_name: type))
        when Type::Simple
          Type.simple(fully_qualified_name_for(local_name: type.name))
        else
          # TODO: normalize internal parts of complex/compound types
          type
        end
      end

      def debug
        puts yield if DEBUG
      end
    end
  end

  class Tree
    #: -> void
    def flatten_namespaces!
      visitor = Rewriters::FlattenNamespaces.new(self)
      visitor.visit(self)
    end
  end
end
