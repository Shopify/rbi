# typed: strict
# frozen_string_literal: true

module RBI
  class MockClient < Client
    extend T::Sig

    sig { params(path: String).returns(MockClient) }
    def self.from_file(path)
      json = File.read(path)
      content = JSON.parse(json)
      MockClient.new(content)
    end

    sig { override.returns(Index) }
    attr_reader :index

    sig { params(content: T::Hash[String, T.nilable(String)]).void }
    def initialize(content)
      super()
      @content = content
      @index = T.let(build_index(content), Index)
      @logger = T.let(Logger.new(color: false), Logger)
    end

    sig { override.params(name: String, version: String).returns(T.nilable(String)) }
    def pull_rbi_content(name, version)
      @content["#{name}@#{version}"]
    end

    sig { override.params(name: String, version: String, path: String).void }
    def push_rbi_content(name, version, path); end

    private

    sig { params(content: T::Hash[String, T.nilable(String)]).returns(Index) }
    def build_index(content)
      index = Index.new
      content.each do |key, _|
        name, version = key.split("@")
        index.index(T.must(name), T.must(version), "path/to/#{name}@#{version}.rbi")
      end
      index
    end
  end
end
