# typed: strict
# frozen_string_literal: true

module RBI
  class Fetcher
    extend T::Sig
    extend T::Helpers

    abstract!

    sig { abstract.params(name: String, version: String).returns(T.nilable(String)) }
    def pull_rbi_content(name, version); end
  end
end
