# typed: strict
# frozen_string_literal: true

module RBI
  class Loc
    extend T::Sig

    sig { returns(T.nilable(String)) }
    attr_reader :file

    sig { returns(T.nilable(Integer)) }
    attr_reader :begin_line, :end_line, :begin_column, :end_column

    sig do
      params(
        file: T.nilable(String),
        begin_line: T.nilable(Integer),
        end_line: T.nilable(Integer),
        begin_column: T.nilable(Integer),
        end_column: T.nilable(Integer)
      ).void
    end
    def initialize(file: nil, begin_line: nil, end_line: nil, begin_column: nil, end_column: nil)
      @file = file
      @begin_line = begin_line
      @end_line = end_line
      @begin_column = begin_column
      @end_column = end_column
    end

    sig { returns(String) }
    def to_s
      "#{file}:#{begin_line}:#{begin_column}-#{end_line}:#{end_column}"
    end

    sig { returns(T.nilable(String)) }
    def source
      file = self.file
      return nil unless file
      return nil unless ::File.file?(file)

      return ::File.read(file) unless begin_line && end_line

      string = String.new
      ::File.foreach(file).with_index do |line, line_number|
        string << line if line_number + 1 >= begin_line && line_number + 1 <= end_line
      end
      string
    end
  end
end
