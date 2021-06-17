# typed: true
# frozen_string_literal: true

module RBI
  module Test
    class MockGithubClient
      extend T::Sig
      extend T::Helpers
      include GithubClient

      def initialize(&blk)
        @blk = blk
      end

      def file_content(_repo, path)
        @blk.call(path)
      end
    end
  end
end
