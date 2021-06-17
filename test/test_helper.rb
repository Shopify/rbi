# typed: strict
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require "rbi"
require "minitest/test"

require_relative "mock_github_client"

module RBI
  module TestHelper
    extend T::Sig
    extend T::Helpers

    requires_ancestor Minitest::Test

    TEST_PROJECTS_PATH = "/tmp/rbi/tests"

    sig { params(name: String).returns(MockContext) }
    def project(name)
      MockContext.new("#{TEST_PROJECTS_PATH}/#{name}")
    end

    sig { params(project: MockContext, logger: T.nilable(Logger)).returns(Context) }
    def context(project, logger: nil)
      logger, _ = self.logger unless logger
      Context.new(project.path, logger: logger)
    end

    sig { params(level: Integer, quiet: T::Boolean, color: T::Boolean).returns([Logger, StringIO]) }
    def logger(level: Logger::INFO, quiet: false, color: false)
      out = StringIO.new
      [Logger.new(level: level, quiet: quiet, color: color, out: out), out]
    end

    sig { returns(String) }
    def dummy_json_index
      <<~JSON
        {
          "foo": {
            "1.0.0": "foo@1.0.0.rbi"
          },
          "bar": {
            "1.0.0": "bar@1.0.0.rbi",
            "2.0.0": "bar@2.0.0.rbi"
          }
        }
      JSON
    end

    sig { returns(Test::MockGithubClient) }
    def default_client_mock
      Test::MockGithubClient.new do |path|
        case path
        when "central_repo/index.json"
          dummy_json_index
        when "central_repo/foo@1.0.0.rbi"
          "FOO = 1"
        when "central_repo/bar@2.0.0.rbi"
          "BAR = 2"
        else
          raise "Unsupported path: `#{path}`"
        end
      end
    end

    sig { params(mock: Test::MockGithubClient, path: String).returns([Client, StringIO]) }
    def client(mock, path)
      logger, out = self.logger
      [Client.new(logger, github_client: mock, project_path: path), out]
    end

    sig { params(exp: String, out: String).void }
    def assert_log(exp, out)
      assert_equal(exp, "#{out.rstrip}\n")
    end
  end
end

require "minitest/autorun"
