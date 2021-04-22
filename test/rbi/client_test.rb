# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class MockGithubClient
    include GithubClient

    def initialize(&blk)
      @blk = blk
    end

    def file_content(_repo, path)
      @blk.call(path)
    end
  end

  class ClientTest < Minitest::Test
    include TestHelper

    def test_init
      mock = MockGithubClient.new do |path|
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

      project = self.project("InitRBI")
      project.write("Gemfile.lock", <<~LOCK)
        GEM
          specs:
            foo (1.0.0)
              bar
            bar (2.0.0)
      LOCK
      client, out = client(mock, project.path)
      res = client.init

      assert(res)
      assert_empty(out.string)
      assert_equal("FOO = 1", File.read("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi"))
      assert_equal("BAR = 2", File.read("#{project.path}/sorbet/rbi/gems/bar@2.0.0.rbi"))

      project.destroy
    end

    def test_pull_from_empty_index
      mock = MockGithubClient.new do |path|
        case path
        when "central_repo/index.json"
          "{}"
        else
          raise "Unsupported path: `#{path}`"
        end
      end

      client, out = client(mock, "")
      res = client.pull_rbi("foo", "1.0.0")

      refute(res)
      assert_equal(<<~ERR.strip, out.string.strip)
        Error: The RBI for `foo@1.0.0` gem doesn't exist in the central repository
        Run `rbi generate foo@1.0.0` to generate it.
      ERR
    end

    def test_pull_rbi
      mock = MockGithubClient.new do |path|
        case path
        when "central_repo/index.json"
          dummy_json_index
        when "central_repo/foo@1.0.0.rbi"
          "FOO = 1"
        else
          raise "Unsupported path: `#{path}`"
        end
      end

      project = self.project("PullRBI")
      client, out = client(mock, project.path)
      res = client.pull_rbi("foo", "1.0.0")

      assert(res)
      assert_empty(out.string)
      assert_equal("FOO = 1", File.read("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi"))

      project.destroy
    end

    private

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

    def client(mock, path)
      out = StringIO.new
      logger = Logger.new(logdev: out, color: false)
      [Client.new(logger, github_client: mock, project_path: path), out]
    end
  end
end
