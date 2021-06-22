# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class GithubTest < Minitest::Test
    include TestHelper

    def test_access_private_repo_without_auth
      project = self.project("test_access_private_repo_without_auth")

      project.gemfile(<<~GEMFILE)
        source "https://rubygems.org"

        gem "rbi", path: "#{File.expand_path(Bundler.root)}"
        gem "foo"
      GEMFILE

      project.gemfile_lock(<<~GEMFILE_LOCK)
        GEM
          remote: https://rubygems.org/
          specs:
            foo (1.0.0)
      GEMFILE_LOCK

      out, err, status = project.run("bundle exec rbi update --no-color")
      refute(status)
      assert_empty(out)
      assert_log(<<~OUT, err)
        Error: Can't fetch RBI content from shopify/rbi

        It looks like we can't access shopify/rbi repo (GET https://api.github.com/repos/shopify/rbi/contents/central_repo/index.json: 404 - Not Found // See: https://docs.github.com/rest/reference/repos#get-repository-content).

        Are you trying to access a private repository?
        If so, please specify your Github credentials in your ~/.netrc file.

        https://github.com/octokit/octokit.rb#using-a-netrc-file
      OUT

      project.destroy
    end
  end
end
