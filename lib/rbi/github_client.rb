# typed: strict
# frozen_string_literal: true

module RBI
  module GithubClient
    extend T::Sig
    extend T::Helpers

    interface!

    sig { abstract.params(repo: String, path: String).returns(T.nilable(String)) }
    def file_content(repo, path); end
  end
end

module Octokit
  class Client
    extend T::Sig
    include RBI::GithubClient

    sig { override.params(repo: String, path: String).returns(T.nilable(String)) }
    def file_content(repo, path)
      base64 = content(repo, path: path).content
      Base64.decode64(base64)
    end
  end
end
