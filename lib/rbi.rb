# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require "stringio"
require "colorize"
require "octokit"
require "base64"

module RBI
  class Error < StandardError; end
end

require_relative "rbi/cli_helper"
require_relative "rbi/logger"
require_relative "rbi/client"
require_relative "rbi/repo"

require_relative "rbi/cli"
require_relative "rbi/version"
