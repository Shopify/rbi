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

      out, err, status = project.run("bundle exec rbi update --no-color --no-netrc")
      refute(status)
      assert_empty(out)
      assert_log(<<~OUT, err)
        Error: Can't fetch RBI content from shopify/rbi

        It looks like we can't access shopify/rbi repo (GET https://api.github.com/repos/shopify/rbi/contents/central_repo/index.json: 404 - Not Found // See: https://docs.github.com/rest/reference/repos#get-repository-content).

        Are you trying to access a private repository?
        If so, please specify your Github credentials in your ~/.netrc file.

        https://github.com/Shopify/rbi#using-a-netrc-file
      OUT

      project.destroy
    end

    def test_access_private_repo_with_bad_netrc
      project = self.project("test_access_private_repo_with_bad_netrc")

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

      out, err, status = project.run("bundle exec rbi update --no-color --netrc-file netrc")
      refute(status)
      assert_empty(out)
      assert_log(<<~OUT, err)
        Error loading credentials from netrc file for https://api.github.com/
        Error: Can't fetch RBI content from shopify/rbi

        It looks like we can't access shopify/rbi repo (GET https://api.github.com/repos/shopify/rbi/contents/central_repo/index.json: 404 - Not Found // See: https://docs.github.com/rest/reference/repos#get-repository-content).

        Are you trying to access a private repository?
        If so, please specify your Github credentials in your ~/.netrc file.

        https://github.com/Shopify/rbi#using-a-netrc-file
      OUT

      project.destroy
    end

    def test_access_private_repo_without_netrc_but_netrc_file
      project = self.project("test_access_private_repo_without_netrc_but_netrc_file")

      out, err, status = project.run("bundle exec rbi update --no-color --no-netrc --netrc-file netrc")
      refute(status)
      assert_empty(out)
      assert_log(<<~OUT, err)
        Error: Option `--netrc-file` can only be used with option `--netrc`
      OUT

      project.destroy
    end

    def test_access_private_repo_not_found
      project = self.project("test_access_private_repo_not_found")

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

      repo = "Shopify/RBIRepoNotFound"

      out, err, status = project.bundle_exec("rbi update --no-color --no-netrc --central-repo-slug #{repo}")
      refute(status)
      assert_empty(out)
      assert_log(<<~OUT, err)
        Error: Can't fetch RBI content from #{repo}

        It looks like we can't access #{repo} repo (GET https://api.github.com/repos/#{repo}/contents/central_repo/index.json: 404 - Not Found // See: https://docs.github.com/rest/reference/repos#get-repository-content).

        Are you trying to access a private repository?
        If so, please specify your Github credentials in your ~/.netrc file.

        https://github.com/Shopify/rbi#using-a-netrc-file
      OUT

      project.destroy
    end
  end
end
