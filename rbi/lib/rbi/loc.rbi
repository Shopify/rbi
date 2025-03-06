# typed: strict
# frozen_string_literal: true

module RBI
  class Loc
    class << self
      sig { params(file: String, prism_location: Prism::Location).returns(Loc) }
      def from_prism(file, prism_location); end
    end

    sig { returns(T.nilable(String)) }
    attr_reader :file

    sig { returns(T.nilable(Integer)) }
    attr_reader :begin_line, :end_line, :begin_column, :end_column

    sig { params(file: T.nilable(String), begin_line: T.nilable(Integer), end_line: T.nilable(Integer), begin_column: T.nilable(Integer), end_column: T.nilable(Integer)).void }
    def initialize(file: nil, begin_line: nil, end_line: nil, begin_column: nil, end_column: nil); end

    sig { returns(String) }
    def to_s; end

    sig { returns(T.nilable(String)) }
    def source; end
  end
end
