# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require "stringio"
require "colorize"

module RBI
  class Error < StandardError; end
end

require_relative "rbi/cli_helper"
require_relative "rbi/logger"

require_relative "rbi/cli"
require_relative "rbi/version"
