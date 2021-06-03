# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  module Test
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

      def test_clean
        project = self.project("test_clean")
        project.write("sorbet/rbi/gems/foo@1.0.0.rbi")
        project.write("sorbet/rbi/gems/foo@2.0.0.rbi")
        project.write("sorbet/rbi/gems/bar@1.0.0.rbi")

        client, _ = client(default_client_mock, project.path)
        client.clean

        refute(File.file?("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi"))
        refute(File.file?("#{project.path}/sorbet/rbi/gems/foo@2.0.0.rbi"))
        refute(File.file?("#{project.path}/sorbet/rbi/gems/bar@1.0.0.rbi"))

        project.destroy
      end

      def test_init_with_non_empty_gem_rbis
        project = self.project("test_init_with_non_empty_gem_rbis")
        project.write("sorbet/rbi/gems/foo@1.0.0.rbi")
        project.write("sorbet/rbi/gems/foo@2.0.0.rbi")
        project.write("sorbet/rbi/gems/bar@1.0.0.rbi")

        client, out = client(default_client_mock, project.path)
        res = client.init

        refute(res)
        assert_log(<<~OUT, out.string)
          Error: Can't init while you RBI gems directory is not empty.

          Hint: Run `rbi clean` to delete it.
        OUT

        assert(File.file?("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi"))
        assert(File.file?("#{project.path}/sorbet/rbi/gems/foo@2.0.0.rbi"))
        assert(File.file?("#{project.path}/sorbet/rbi/gems/bar@1.0.0.rbi"))

        project.destroy
      end

      def test_init
        project = self.project("test_init")
        project.write("Gemfile.lock", <<~LOCK)
          GEM
            specs:
              foo (1.0.0)
                bar
              bar (2.0.0)
        LOCK
        client, out = client(default_client_mock, project.path)
        res = client.init

        assert(res)
        assert_empty(out.string)
        assert_equal("FOO = 1", File.read("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi"))
        assert_equal("BAR = 2", File.read("#{project.path}/sorbet/rbi/gems/bar@2.0.0.rbi"))

        project.destroy
      end

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
        res = client.update

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
        assert_log(<<~OUT, out.string)
          Error: The RBI for `foo@1.0.0` gem doesn't exist in the central repository.

          Hint: Run `rbi generate foo@1.0.0` to generate it.
        OUT
      end

      def test_pull_rbi
        project = self.project("test_pull_rbi")
        client, out = client(default_client_mock, project.path)
        res = client.pull_rbi("foo", "1.0.0")

        assert(res)
        assert_empty(out.string)
        assert_equal("FOO = 1", File.read("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi"))

        project.destroy
      end

      def test_has_local_rbi_for_gem_version
        project = self.project("test_has_local_rbi_for_gem_version")
        project.write("sorbet/rbi/gems/foo@1.0.0.rbi")

        client, out = client(default_client_mock, project.path)
        assert_empty(out.string)

        assert(client.has_local_rbi_for_gem_version?("foo", "1.0.0"))
        refute(client.has_local_rbi_for_gem_version?("foo", "2.0.0"))
        refute(client.has_local_rbi_for_gem_version?("bar", "1.0.0"))

        project.destroy
      end

      def test_has_local_rbi_for_gem
        project = self.project("test_has_local_rbi_for_gem")
        project.write("sorbet/rbi/gems/foo@1.0.0.rbi")

        client, out = client(default_client_mock, project.path)
        assert_empty(out.string)

        assert(client.has_local_rbi_for_gem?("foo"))
        refute(client.has_local_rbi_for_gem?("bar"))

        project.destroy
      end

      def test_remove_local_rbi_for_gem
        project = self.project("test_remove_local_rbi_for_gem")
        project.write("sorbet/rbi/gems/foo@1.0.0.rbi")
        project.write("sorbet/rbi/gems/foo@2.0.0.rbi")

        client, out = client(default_client_mock, project.path)
        assert_empty(out.string)

        assert(File.file?("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi"))
        assert(File.file?("#{project.path}/sorbet/rbi/gems/foo@2.0.0.rbi"))
        refute(File.file?("#{project.path}/sorbet/rbi/gems/bar@1.0.0.rbi"))

        client.remove_local_rbi_for_gem("foo")
        client.remove_local_rbi_for_gem("bar")

        refute(File.file?("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi"))
        refute(File.file?("#{project.path}/sorbet/rbi/gems/foo@2.0.0.rbi"))
        refute(File.file?("#{project.path}/sorbet/rbi/gems/bar@1.0.0.rbi"))

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

      def default_client_mock
        MockGithubClient.new do |path|
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

      def client(mock, path)
        logger, out = self.logger
        [Client.new(logger, github_client: mock, project_path: path), out]
      end
    end
  end
end
