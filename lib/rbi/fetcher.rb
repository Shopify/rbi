# typed: strict
# frozen_string_literal: true

module RBI
  class Fetcher
    extend T::Sig
    extend T::Helpers

    abstract!

    sig { abstract.params(name: String, version: String).returns(T.nilable(String)) }
    def pull_rbi_content(name, version); end

    sig { abstract.params(name: String, version: String, path: String).void }
    def push_rbi_content(name, version, path); end
  end
end
