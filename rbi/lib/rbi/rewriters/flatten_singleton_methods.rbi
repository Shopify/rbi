# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    # Rewrite non-singleton methods inside singleton classes to singleton methods
    #
    # Example:
    # ~~~rb
    # class << self
    #  def m1; end
    #  def self.m2; end
    #
    #  class << self
    #    def m3; end
    #  end
    # end
    # ~~~
    #
    # will be rewritten to:
    #
    # ~~~rb
    # def self.m1; end
    #
    # class << self
    #   def self.m2; end
    #   def self.m3; end
    # end
    # ~~~
    class FlattenSingletonMethods < Visitor
      # @override
      sig { params(node: T.nilable(Node)).void }
      def visit(node); end
    end
  end

  class Tree
    sig { void }
    def flatten_singleton_methods!; end
  end
end
