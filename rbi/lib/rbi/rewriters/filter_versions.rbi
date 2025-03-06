# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    # Take a gem version and filter out all RBI that is not relevant to that version based on @version annotations
    # in comments. As an example:
    #
    # ~~~rb
    # tree = Parser.parse_string(<<~RBI)
    #   class Foo
    #     # @version > 0.3.0
    #     def bar
    #     end
    #
    #     # @version <= 0.3.0
    #     def bar(arg1)
    #     end
    #   end
    # RBI
    #
    # Rewriters::FilterVersions.filter(tree, Gem::Version.new("0.3.1"))
    #
    # assert_equal(<<~RBI, tree.string)
    #   class Foo
    #     # @version > 0.3.0
    #     def bar
    #     end
    #   end
    # RBI
    # ~~~
    #
    # Supported operators:
    # - equals `=`
    # - not equals `!=`
    # - greater than `>`
    # - greater than or equal to `>=`
    # - less than `<`
    # - less than or equal to `<=`
    # - pessimistic or twiddle-wakka`~>`
    #
    # And/or logic:
    # - "And" logic: put multiple versions on the same line
    #   - e.g. `@version > 0.3.0, <1.0.0` means version must be greater than 0.3.0 AND less than 1.0.0
    # - "Or" logic: put multiple versions on subsequent lines
    #   - e.g. the following means version must be less than 0.3.0 OR greater than 1.0.0
    #       ```
    #       # @version < 0.3.0
    #       # @version > 1.0.0
    #       ```
    # Prerelease versions:
    # - Prerelease versions are considered less than their non-prerelease counterparts
    #   - e.g. `0.4.0-prerelease` is less than `0.4.0`
    #
    # RBI with no versions:
    # - RBI with no version annotations are automatically counted towards ALL versions
    class FilterVersions < Visitor
      VERSION_PREFIX = "version "

      class << self
        sig { params(tree: Tree, version: Gem::Version).void }
        def filter(tree, version); end
      end

      sig { params(version: Gem::Version).void }
      def initialize(version); end

      # @override
      sig { params(node: T.nilable(Node)).void }
      def visit(node); end
    end
  end

  class Node
    sig { params(version: Gem::Version).returns(T::Boolean) }
    def satisfies_version?(version); end
  end

  class NodeWithComments
    sig { returns(T::Array[Gem::Requirement]) }
    def version_requirements; end
  end

  class Tree
    sig { params(version: Gem::Version).void }
    def filter_versions!(version); end
  end
end
