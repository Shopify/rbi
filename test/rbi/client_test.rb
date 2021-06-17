# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  module Test
    class ClientTest < Minitest::Test
      include TestHelper

      def test_update
        project = self.project("test_update")
        project.write("sorbet/rbi/gems/foo@1.0.0.rbi")
        project.write("sorbet/rbi/gems/bar@1.0.0.rbi")

        project.write("Gemfile.lock", <<~LOCK)
          GEM
            specs:
              foo (1.0.0)
                bar
              bar (2.0.0)
        LOCK

        client, _ = client(default_client_mock, project.path)
        res = client.update(context(project))

        assert(res)

        assert(File.file?("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi"))
        refute(File.file?("#{project.path}/sorbet/rbi/gems/bar@1.0.0.rbi"))
        assert(File.file?("#{project.path}/sorbet/rbi/gems/bar@2.0.0.rbi"))

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
        assert_empty(out.string)
      end

      def test_pull_rbi
        project = self.project("test_pull_rbi")
        client, out = client(default_client_mock, project.path)
        res = client.pull_rbi("foo", "1.0.0")

        assert(res)
        assert_log(<<~OUT, out.string)
          Success: Pulled `foo@1.0.0.rbi` from central repository
        OUT
        assert_equal("FOO = 1", File.read("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi"))

        project.destroy
      end
    end
  end
end
