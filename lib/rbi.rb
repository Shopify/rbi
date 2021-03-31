# typed: true
# typed: false
# frozen_string_literal: true

require "sorbet-runtime"
require "parser/current"
require "stringio"

module RBI
  class Error < StandardError; end
end

require_relative "rbi/model"
require_relative "rbi/parser"
require_relative "rbi/visitor"
require_relative "rbi/printer"
require_relative "rbi/index"

require_relative "rbi/validators/duplicates"

require_relative "rbi/cli"
require_relative "rbi/version"