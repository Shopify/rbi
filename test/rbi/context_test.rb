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
    end
  end
end
