# typed: strict
# frozen_string_literal: true

module RBI
  class GroupNodesError < Error; end

  module Rewriters
    class GroupNodes < Visitor
      # @override
      sig { params(node: T.nilable(Node)).void }
      def visit(node); end

      private

      sig { params(node: Node).returns(Group::Kind) }
      def group_kind(node); end
    end
  end

  class Tree
    sig { void }
    def group_nodes!; end
  end

  class Group < Tree
    sig { returns(Kind) }
    attr_reader :kind

    sig { params(kind: Kind).void }
    def initialize(kind); end

    class Kind < T::Enum
      enums do
        Mixins = new
        RequiredAncestors = new
        Helpers = new
        TypeMembers = new
        MixesInClassMethods = new
        Sends = new
        Attrs = new
        TStructFields = new
        TEnums = new
        Inits = new
        Methods = new
        SingletonClasses = new
        Consts = new
      end
    end
  end
end
