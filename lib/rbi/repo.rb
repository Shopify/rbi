# typed: strict
# frozen_string_literal: true

require "json"

module RBI
  class Repo
    extend T::Sig

    sig { params(repo_path: String, index_path: String).returns(Repo) }
    def self.from_index_file(repo_path, index_path = "index.json")
      full_path = "#{repo_path}/#{index_path}"
      repo = Repo.new(repo_path)
      repo.populate_index(JSON.parse(File.read(full_path)))
      repo
    end

    sig { params(repo_path: String).void }
    def initialize(repo_path)
      @index = T.let({}, T::Hash[String, T::Hash[String, String]])
      @repo_path = repo_path
    end

    sig { params(hash: T::Hash[String, T::Hash[String, String]]).void }
    def populate_index(hash)
      @index = hash
    end

    sig { params(name: String, version: String).returns(T.nilable(String)) }
    def rbi_path(name, version)
      @index.fetch(name, nil)&.fetch(version, nil)
    end
  end
end
