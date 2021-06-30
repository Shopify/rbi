# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  module Test
    class ContextTest < Minitest::Test
      include TestHelper
      extend T::Sig

      def test_clean
        project = self.project("test_clean")
        project.write("sorbet/rbi/gems/foo@1.0.0.rbi")
        project.write("sorbet/rbi/gems/foo@2.0.0.rbi")
        project.write("sorbet/rbi/gems/bar@1.0.0.rbi")

        context, out = mock_context(project)
        context.clean

        assert_log(<<~OUT, out.string)
          Success: Clean `sorbet/rbi/gems` directory
        OUT

        refute(File.file?("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi"))
        refute(File.file?("#{project.path}/sorbet/rbi/gems/foo@2.0.0.rbi"))
        refute(File.file?("#{project.path}/sorbet/rbi/gems/bar@1.0.0.rbi"))

        project.destroy
      end

      def test_has_local_rbi_for_gem_version
        project = self.project("test_has_local_rbi_for_gem_version")
        project.write("sorbet/rbi/gems/foo@1.0.0.rbi")

        context, _ = mock_context(project)
        assert(context.has_local_rbi_for_gem_version?("foo", "1.0.0"))
        refute(context.has_local_rbi_for_gem_version?("foo", "2.0.0"))
        refute(context.has_local_rbi_for_gem_version?("bar", "1.0.0"))

        project.destroy
      end

      def test_has_local_rbi_for_gem
        project = self.project("test_has_local_rbi_for_gem")
        project.write("sorbet/rbi/gems/foo@1.0.0.rbi")

        context, _ = mock_context(project)
        assert(context.has_local_rbi_for_gem?("foo"))
        refute(context.has_local_rbi_for_gem?("bar"))

        project.destroy
      end

      def test_has_local_rbis
        project = self.project("test_has_local_rbis")
        context, _ = mock_context(project)

        refute(context.has_local_rbis?)

        project.write("sorbet/rbi/gems/foo@1.0.0.rbi")
        assert(context.has_local_rbis?)

        project.destroy
      end

      def test_remove_local_rbi_for_gem
        project = self.project("test_remove_local_rbi_for_gem")
        project.write("sorbet/rbi/gems/foo@1.0.0.rbi")
        project.write("sorbet/rbi/gems/foo@2.0.0.rbi")

        context, _ = mock_context(project)
        context.remove_local_rbi_for_gem("foo")
        context.remove_local_rbi_for_gem("bar")

        refute(File.file?("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi"))
        refute(File.file?("#{project.path}/sorbet/rbi/gems/foo@2.0.0.rbi"))
        refute(File.file?("#{project.path}/sorbet/rbi/gems/bar@1.0.0.rbi"))

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

        context, out = mock_context(project)
        res = context.init

        assert(res)
        assert_log(<<~OUT, out.string)
          Success: Pulled `bar@2.0.0.rbi` from central repository
          Success: Pulled `foo@1.0.0.rbi` from central repository
          Success: Gem RBIs successfully updated
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

        context, out = mock_context(project)
        res = context.update

        assert(res)
        assert_log(<<~OUT, out.string)
          Success: Pulled `bar@2.0.0.rbi` from central repository
          Success: Gem RBIs successfully updated
        OUT
        assert(File.file?("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi"))
        refute(File.file?("#{project.path}/sorbet/rbi/gems/bar@1.0.0.rbi"))
        assert(File.file?("#{project.path}/sorbet/rbi/gems/bar@2.0.0.rbi"))

        project.destroy
      end

      private

      sig { params(project: TMPDir).returns([Context, StringIO]) }
      def mock_context(project)
        logger, out = self.logger
        context = Context.new(project.path, logger: logger, fetcher: mock_fetcher)
        [context, out]
      end

      sig { returns(Fetcher) }
      def mock_fetcher
        MockFetcher.new({
          "foo@1.0.0" => "FOO = 1",
          "bar@2.0.0" => "BAR = 2",
        })
      end
    end
  end
end
