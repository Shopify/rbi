# typed: strict
# frozen_string_literal: true

module RBI
  class MockGithubClient
    extend T::Sig
    include GithubClient

    sig { override.params(_repo: String, path: String).returns(T.nilable(String)) }
    def file_content(_repo, path)
      File.read(path)
    end
  end
end
