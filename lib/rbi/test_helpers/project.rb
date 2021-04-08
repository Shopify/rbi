# typed: strict
# frozen_string_literal: true

require "fileutils"
require "open3"

module RBI
  module TestHelpers
    class Project
      extend T::Sig

      # Create a new test project at `path`
      sig { params(path: String).void }
      def initialize(path)
        @path = path
        FileUtils.rm_rf(@path)
        FileUtils.mkdir_p(@path)
      end

      # Set the content of the Gemfile in this project
      sig { params(content: String).void }
      def gemfile(content)
        write("Gemfile", content)
      end

      # Write `content` in the file at `rel_path`
      sig { params(rel_path: String, content: String).void }
      def write(rel_path, content = "")
        path = absolute_path(rel_path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content)
      end

      # Run a command with `bundle exec` in this project
      sig { params(cmd: String, args: String).returns([T.nilable(String), T::Boolean]) }
      def bundle_exec(cmd, *args)
        opts = {}
        opts[:chdir] = @path
        out, _, status = Open3.capture3(["bundle", "exec", cmd, *args].join(" "), opts)
        [out, status.success?]
      end

      # Run `bundle install` in this project
      sig { returns([T.nilable(String), T.nilable(String), T::Boolean]) }
      def bundle_install
        opts = {}
        opts[:chdir] = @path
        out, err, status = Open3.capture3("bundle", "install", "--path", "vendor/bundle", opts)
        [out, err, status.success?]
      end

      # Delete this project and its content
      sig { void }
      def destroy
        FileUtils.rm_rf(@path)
      end

      private

      # Create an absolute path from `self.path` and `rel_path`
      sig { params(rel_path: String).returns(String) }
      def absolute_path(rel_path)
        (Pathname.new(@path) / rel_path).to_s
      end
    end
  end
end
