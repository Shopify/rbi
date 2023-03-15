# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    class FilterVersions < Visitor
      extend T::Sig

      sig { params(version: Gem::Version).void }
      def initialize(version)
        super()
        @version = version
      end

      sig { override.params(node: T.nilable(Node)).void }
      def visit(node)
        return unless node

        unless node.satisfies_version?(@version)
          node.detach
          return
        end

        visit_all(node.nodes.dup) if node.is_a?(Tree)
      end
    end
  end

  class Node
    sig { params(version: Gem::Version).returns(T::Boolean) }
    def satisfies_version?(version)
      return true unless is_a?(NodeWithComments)

      requirements = version_requirements
      requirements.empty? || requirements.any? { |req| req.satisfied_by?(version) }
    end
  end

  class NodeWithComments
    sig { returns(T::Array[Gem::Requirement]) }
    def version_requirements
      annotations.select do |annotation|
        annotation.start_with?("version")
        # TODO: check that annotation has the correct format (operator x.y.z)
      end.map do |annotation|
        versions = annotation.delete_prefix("version ").split(/, */)
        Gem::Requirement.new(versions)
      end
    end
  end
end
