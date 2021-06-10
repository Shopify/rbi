# typed: strict
# frozen_string_literal: true

require "fileutils"
require "open3"

module RBI
  class Context
    extend T::Sig

    sig { returns(String) }
    attr_reader :path

    sig { params(path: String).void }
    def initialize(path)
      @path = path
      FileUtils.rm_rf(@path)
      FileUtils.mkdir_p(@path)
    end

    sig { params(content: String).void }
    def gemfile(content)
      write("Gemfile", content)
    end

    sig { params(rel_path: String, content: String).void }
    def write(rel_path, content = "")
      path = absolute_path(rel_path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end

    sig { params(cmd: String, args: String).returns([String, String, T::Boolean]) }
    def run(cmd, *args)
      opts = {}
      opts[:chdir] = @path
      out, err, status = Open3.capture3([cmd, *args].join(" "), opts)
      [out, err, status.success?]
    end

    sig { void }
    def destroy
      FileUtils.rm_rf(@path)
    end

    sig { params(rel_path: String).returns(String) }
    def absolute_path(rel_path)
      (Pathname.new(@path) / rel_path).to_s
    end
  end
end
