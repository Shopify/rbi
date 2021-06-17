# typed: strict
# frozen_string_literal: true

module RBI
  class MockFetcher < Fetcher
    extend T::Sig

    sig { params(path: String).returns(MockFetcher) }
    def self.from_file(path)
      json = File.read(path)
      content = JSON.parse(json)
      MockFetcher.new(content)
    end

    sig { params(content: T::Hash[String, T.nilable(String)]).void }
    def initialize(content)
      super()
      @content = content
    end

    sig { override.params(name: String, version: String).returns(T.nilable(String)) }
    def pull_rbi_content(name, version)
      @content["#{name}@#{version}"]
    end
  end
end
