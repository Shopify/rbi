# typed: strict
# frozen_string_literal: true

module RBI
  # The context (ie repo or project) where `rbi` is running
  class Context
    extend T::Sig

    sig { returns(String) }
    attr_reader :path

    sig { params(path: String).void }
    def initialize(path)
      @path = path
    end
  end
end
