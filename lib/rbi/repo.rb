# typed: strict
# frozen_string_literal: true

module RBI
  class Repo
    extend T::Sig

    sig { params(json: String).returns(Repo) }
    def self.from_index(json)
      repo = Repo.new
      repo.populate_index(JSON.parse(json))
      repo
    end

    sig { void }
    def initialize
      @index = T.let({}, T::Hash[String, T::Hash[String, String]])
    end

    sig { params(hash: T::Hash[String, T::Hash[String, String]]).void }
    def populate_index(hash)
      @index = hash
    end

    sig { params(name: String, version: String).returns(T.nilable(String)) }
    def rbi_path(name, version)
      @index.fetch(name, nil)&.fetch(version, nil)
    end

    sig { returns(T::Array[String]) }
    def gems
      @index.keys
    end
  end
end
