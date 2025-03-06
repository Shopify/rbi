# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    class NestNonPublicMembers < Visitor
      # @override
      sig { params(node: T.nilable(Node)).void }
      def visit(node); end
    end
  end

  class Tree
    sig { void }
    def nest_non_public_members!; end
  end

  class VisibilityGroup < Tree
    sig { returns(Visibility) }
    attr_reader :visibility

    sig { params(visibility: Visibility).void }
    def initialize(visibility); end
  end
end
