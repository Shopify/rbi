# typed: strict
# frozen_string_literal: true

module RBI
  class Index
    extend T::Sig
    extend T::Generic
    include Enumerable

    Elem = type_member(fixed: String)

    sig { params(json: String).returns(Index) }
    def self.from_json(json)
      Index.from_hash(JSON.parse(json))
    end

    sig { params(hash: T::Hash[String, T::Hash[String, String]]).returns(Index) }
    def self.from_hash(hash)
      index = Index.new
      hash.each do |name, versions|
        versions.each do |version, path|
          index.index(name, version, path)
        end
      end
      index
    end

    sig { void }
    def initialize
      @entries = T.let({}, T::Hash[String, T::Hash[String, String]])
    end

    sig { params(name: String, version: String, path: String).void }
    def index(name, version, path)
      version_hash = @entries[name] ||= {}
      version_hash[version] = path
    end

    sig { override.params(block: T.proc.params(name: String, versions: T::Hash[String, String]).void).void }
    def each(&block)
      @entries.each { |name, versions| block.call(name, versions) }
    end

    sig { returns(T::Array[String]) }
    def gems
      @entries.keys
    end

    sig { returns(Integer) }
    def size
      gems.size
    end

    sig { params(name: String).returns(T::Boolean) }
    def has_gem?(name)
      @entries.key?(name)
    end

    sig { params(name: String).returns(T::Array[String]) }
    def versions_for_gem(name)
      versions = @entries[name]
      return [] unless versions
      versions.keys.sort
    end

    sig { params(name: String).returns(T.nilable(String)) }
    def last_version_for_gem(name)
      versions_for_gem(name).last
    end

    sig { params(name: String, version: String).returns(T::Boolean) }
    def has_version_for_gem?(name, version)
      versions = @entries[name]
      return false unless versions
      versions.key?(version)
    end

    sig { params(name: String, version: String).returns(T.nilable(String)) }
    def rbi_path(name, version)
      @entries.fetch(name, nil)&.fetch(version, nil)
    end

    sig { returns(String) }
    def to_pretty_json
      JSON.pretty_generate(@entries) << "\n"
    end
  end
end
