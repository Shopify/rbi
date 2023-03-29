# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    class LintVersions < Visitor
      extend T::Sig

      class InvalidVersion < RBI::Error
        extend T::Sig

        sig { returns(Loc) }
        attr_reader :location

        sig { params(message: String, location: Loc).void }
        def initialize(message, location)
          super(message)
          @location = location
        end
      end

      OPERATOR_REGEX = T.let(/^(<|>|<=|>=|=)$/.freeze, Regexp)

      sig { override.params(node: T.nilable(Node)).void }
      def visit(node)
        return unless node
        return unless node.is_a?(NodeWithComments)

        node.comments.each do |comment|
          next unless comment.text.start_with?(/@version(-|\b)/)

          text = comment.text.delete_prefix("@version").strip
          versions = text.split(/, */)

          if versions.empty?
            raise InvalidVersion.new(
              "Invalid version string `#{text}` in annotation `#{comment.text}`",
              T.must(comment.loc)
            )
          end

          versions.each do |version_line|
            operator_str, version_str = version_line.split(" ")
            version = parse_version(version_str, comment)
            operator = parse_operator(operator_str, comment)
          end
        end

        visit_all(node.nodes.dup) if node.is_a?(Tree)
      end

      private

      sig { params(version_str: T.nilable(String), comment: Comment).returns(Gem::Version) }
      def parse_version(version_str, comment)
        unless version_str
          raise InvalidVersion.new(
            "Invalid version string `#{version_str}` in annotation `#{comment.text}`",
            T.must(comment.loc)
          )
        end

        Gem::Version.new(version_str)
      rescue ArgumentError
        raise InvalidVersion.new(
          "Invalid version string `#{version_str}` in annotation `#{comment.text}`",
          T.must(comment.loc)
        )
      end

      sig {params(operator_str: T.nilable(String), comment: Comment).returns(String)}
      def parse_operator(operator_str, comment)
        unless OPERATOR_REGEX =~ operator_str
          raise InvalidVersion.new(
            "Invalid operator `#{operator_str}` in annotation `#{comment.text}`",
            T.must(comment.loc)
          )
        end

        T.must(operator_str)
      end
    end
  end
end
