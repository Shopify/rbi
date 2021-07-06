# typed: strict
# frozen_string_literal: true

require "base64"
require "bundler"
require "colorize"
require "fileutils"
require "json"
require "octokit"
require "open3"
require "open3"
require "sorbet-runtime"
require "stringio"
require "tapioca/internal"
require "thor"

module RBI
  class Error < StandardError; end
end

require_relative "rbi/logger"
require_relative "rbi/client"
require_relative "rbi/github_client"
require_relative "rbi/mock_client"
require_relative "rbi/tree_cleaner"
require_relative "rbi/context"
require_relative "rbi/tmp_dir"
require_relative "rbi/cli_helper"
require_relative "rbi/cli"
require_relative "rbi/version"
