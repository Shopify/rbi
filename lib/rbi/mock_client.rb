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

    sig { params(content: T::Hash[String, T.nilable(String)]).void }
    def initialize(content)
      super()
      @content = content
      @logger = T.let(Logger.new(color: false), Logger)
    end

    sig { override.params(name: String, version: String).returns(T.nilable(String)) }
    def pull_rbi_content(name, version)
      @content["#{name}@#{version}"]
    end

    sig { override.params(name: String, version: String, path: String).void }
    def push_rbi_content(name, version, path); end

    sig { override.params(name: String).returns(T.nilable(String)) }
    def last_version_for_gem(name)
      @content.keys.select { |key| key.start_with?(name) }.sort.last&.split("@")&.last
    end
  end
end
