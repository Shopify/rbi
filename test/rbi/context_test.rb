# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  module Test
    class ContextTest < Minitest::Test
      include TestHelper

      def test_clean
        project = self.project("test_clean")
        project.write("sorbet/rbi/gems/foo@1.0.0.rbi")
        project.write("sorbet/rbi/gems/foo@2.0.0.rbi")
        project.write("sorbet/rbi/gems/bar@1.0.0.rbi")

        context = self.context(project)
        context.clean

        refute(File.file?("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi"))
        refute(File.file?("#{project.path}/sorbet/rbi/gems/foo@2.0.0.rbi"))
        refute(File.file?("#{project.path}/sorbet/rbi/gems/bar@1.0.0.rbi"))

        project.destroy
      end

      def test_has_local_rbi_for_gem_version
        project = self.project("test_has_local_rbi_for_gem_version")
        project.write("sorbet/rbi/gems/foo@1.0.0.rbi")

        context = self.context(project)
        assert(context.has_local_rbi_for_gem_version?("foo", "1.0.0"))
        refute(context.has_local_rbi_for_gem_version?("foo", "2.0.0"))
        refute(context.has_local_rbi_for_gem_version?("bar", "1.0.0"))

        project.destroy
      end

      def test_has_local_rbi_for_gem
        project = self.project("test_has_local_rbi_for_gem")
        project.write("sorbet/rbi/gems/foo@1.0.0.rbi")

        context = self.context(project)
        assert(context.has_local_rbi_for_gem?("foo"))
        refute(context.has_local_rbi_for_gem?("bar"))

        project.destroy
      end

      def test_has_local_rbis
        project = self.project("test_has_local_rbis")
        context = self.context(project)

        refute(context.has_local_rbis?)

        project.write("sorbet/rbi/gems/foo@1.0.0.rbi")
        assert(context.has_local_rbis?)

        project.destroy
      end

      def test_remove_local_rbi_for_gem
        project = self.project("test_remove_local_rbi_for_gem")
        project.write("sorbet/rbi/gems/foo@1.0.0.rbi")
        project.write("sorbet/rbi/gems/foo@2.0.0.rbi")

        context = self.context(project)
        context.remove_local_rbi_for_gem("foo")
        context.remove_local_rbi_for_gem("bar")

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

        logger, out = self.logger
        context = self.context(project, logger: logger)
        fetcher = self.fetcher(default_client_mock)
        res = context.init(fetcher)

        refute(res)
        assert_log(<<~OUT, out.string)
          Error: Can't init while you RBI gems directory is not empty
          Hint: Run `rbi clean` to delete it
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

        logger, out = self.logger
        context = self.context(project, logger: logger)
        fetcher = self.fetcher(default_client_mock)
        res = context.init(fetcher)

        assert(res)
        assert_log(<<~OUT, out.string)
          Success: Pulled `bar@2.0.0.rbi` from central repository
          Success: Pulled `foo@1.0.0.rbi` from central repository
        OUT
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
        context = self.context(project)
        fetcher = self.fetcher(default_client_mock)
        res = context.update(client, fetcher)

        assert(res)

        assert(File.file?("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi"))
        refute(File.file?("#{project.path}/sorbet/rbi/gems/bar@1.0.0.rbi"))
        assert(File.file?("#{project.path}/sorbet/rbi/gems/bar@2.0.0.rbi"))

        project.destroy
      end
    end
  end
end
