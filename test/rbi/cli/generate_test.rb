# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class GenerateTest < Minitest::Test
    extend T::Sig
    include TestHelper

    def test_generate_gem_from_rubygem
      project = self.project("test_generate_gem_from_rubygem")

      project.gemfile(<<~GEMFILE)
        source "https://rubygems.org"

        gem "rbi", path: "#{File.expand_path(Bundler.root)}"
      GEMFILE

      Bundler.with_unbundled_env do
        project.run("bundle config set --local path 'vendor/bundle'")
        project.run("bundle install")

        _, err, status = project.bundle_exec("rbi generate colorize --no-color")
        assert_log(<<~OUT, censor_version(err))
          Success: Generated `colorize@X.Y.Z.rbi`
        OUT
        assert(status)
      end
      file = T.must(Dir["#{project.path}/colorize@*.rbi"].first)
      assert(File.file?(file))

      project.destroy
    end

    def test_generate_gem_from_rubygem_with_version
      project = self.project("test_generate_gem_from_rubygem")

      project.gemfile(<<~GEMFILE)
        source "https://rubygems.org"

        gem "rbi", path: "#{File.expand_path(Bundler.root)}"
      GEMFILE

      name = "colorize"
      version = "0.8.0"
      filename = "#{name}@#{version}"
      Bundler.with_unbundled_env do
        project.run("bundle config set --local path 'vendor/bundle'")
        project.run("bundle install")
        refute(File.file?("#{project.absolute_path(filename)}.rbi"))

        _, err, status = project.bundle_exec("rbi generate #{name} #{version} --no-color")
        assert_log(<<~OUT, err)
          Success: Generated `#{filename}.rbi`
        OUT
        assert(status)
      end
      assert(File.file?("#{project.path}/#{filename}.rbi"))

      project.destroy
    end

    def test_generate_gem_from_source
      project = self.project("test_generate_gem_from_source")

      project.gemfile(<<~GEMFILE)
        source "https://rubygems.org"

        gem "rbi", path: "#{File.expand_path(Bundler.root)}"
      GEMFILE

      name = "colorize"
      version = "0.8.0"
      filename = "#{name}@#{version}"
      Bundler.with_unbundled_env do
        project.run("bundle config set --local path 'vendor/bundle'")
        project.run("bundle install")
        refute(File.file?("#{project.absolute_path(filename)}.rbi"))

        url = "https://rubygems.org"
        _, err, status = project.bundle_exec("rbi generate #{name} #{version} --source=#{url} --no-color")
        assert_log(<<~OUT, err)
          Success: Generated `#{filename}.rbi`
        OUT
        assert(status)
      end
      assert(File.file?("#{project.path}/#{filename}.rbi"))

      project.destroy
    end

    def test_generate_gem_from_git
      project = self.project("test_generate_gem_from_git")

      project.gemfile(<<~GEMFILE)
        source "https://rubygems.org"

        gem "rbi", path: "#{File.expand_path(Bundler.root)}"
      GEMFILE

      name = "colorize"
      version = "0.8.1"
      filename = "#{name}@#{version}"
      Bundler.with_unbundled_env do
        project.run("bundle config set --local path 'vendor/bundle'")
        project.run("bundle install")
        refute(File.file?("#{project.absolute_path(filename)}.rbi"))

        url = "https://github.com/fazibear/colorize.git"
        _, err, status = project.bundle_exec("rbi generate #{name} #{version} --git=#{url} --no-color")
        assert_log(<<~OUT, censor_version(err))
          Success: Generated `colorize@X.Y.Z.rbi`
        OUT
        assert(status)
      end

      project.destroy
    end

    def test_generate_gem_from_git_with_branch
      project = self.project("test_generate_gem_from_git_with_branch")

      project.gemfile(<<~GEMFILE)
        source "https://rubygems.org"

        gem "rbi", path: "#{File.expand_path(Bundler.root)}"
      GEMFILE

      name = "colorize"
      version = "0.8.1"
      filename = "#{name}@#{version}"
      Bundler.with_unbundled_env do
        project.run("bundle config set --local path 'vendor/bundle'")
        project.run("bundle install")
        refute(File.file?("#{project.absolute_path(filename)}.rbi"))

        url = "https://github.com/fazibear/colorize.git"
        _, err, status = project.bundle_exec("rbi generate #{name} #{version} --git=#{url}" \
          " --branch=master --no-color")
        assert_log(<<~OUT, censor_version(err))
          Success: Generated `colorize@X.Y.Z.rbi`
        OUT
        assert(status)
      end

      project.destroy
    end

    def test_generate_gem_from_path
      project = self.project("test_generate_gem_from_path")

      project.write("vendor/cache/foo.gemspec", <<~FOO)
        Gem::Specification.new do |spec|
          spec.name          = "foo"
          spec.version       = "1.0.0"
          spec.authors       = ["Test User"]
          spec.email         = ["test@example.com"]

          spec.summary       = "Foo - Test Gem"
          spec.homepage      = "https://example.com/foo"
          spec.license       = "MIT"

          spec.metadata["allowed_push_host"] = "no"

          spec.require_paths = ["lib"]

          spec.files         = Dir.glob("lib/**/*.rb")
        end
      FOO

      project.gemfile(<<~GEMFILE)
        source "https://rubygems.org"

        gem "rbi", path: "#{File.expand_path(Bundler.root)}"
      GEMFILE

      name = "foo"
      version = "1.0.0"
      filename = "#{name}@#{version}"
      Bundler.with_unbundled_env do
        project.run("bundle config set --local path 'vendor/bundle'")
        project.run("bundle install")
        refute(File.file?("#{project.absolute_path(filename)}.rbi"))

        path = "#{project.path}/vendor/cache/"
        _, err, status = project.bundle_exec("rbi generate #{name} #{version} --path=#{path} --no-color")
        assert_log(<<~OUT, err)
          Success: Generated `foo@1.0.0.rbi`
        OUT
        assert(status)
      end
      assert(File.file?("#{project.path}/#{filename}.rbi"))

      project.destroy
    end

    private

    sig { params(output: String).returns(String) }
    def censor_version(output)
      output.sub(/@[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9]+)?/, "@X.Y.Z")
    end
  end
end
