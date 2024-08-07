# typed: strict
# frozen_string_literal: true

module RBI
  class Printer < Visitor
    extend T::Sig
    extend T::Helpers

    abstract!

    sig do
      params(
        out: T.any(IO, StringIO),
        indent: Integer,
        print_locs: T::Boolean,
        max_line_length: T.nilable(Integer),
      ).void
    end
    def initialize(out: $stdout, indent: 0, print_locs: false, max_line_length: nil)
      super()
      @out = out
      @current_indent = indent
      @print_locs = print_locs
      @max_line_length = max_line_length

      @previous_node = T.let(nil, T.nilable(Node))
    end

    # Visit

    sig { override.params(nodes: T::Array[Node]).void }
    def visit_all(nodes)
      previous_node = @previous_node
      @previous_node = nil
      nodes.each do |node|
        visit(node)
        @previous_node = node
      end
      @previous_node = previous_node
    end

    private

    # Printing

    # Increase indentation level by 2 spaces.
    sig { void }
    def indent
      @current_indent += 2
    end

    # Decrease indentation level by 2 spaces.
    sig { void }
    def dedent
      @current_indent -= 2
    end

    # Print a string without indentation nor `\n` at the end.
    sig { params(string: String).void }
    def print(string)
      @out.print(string)
    end

    # Print a string without indentation but with a `\n` at the end.
    sig { params(string: T.nilable(String)).void }
    def printn(string = nil)
      print(string) if string
      print("\n")
    end

    # Print a string with indentation but without a `\n` at the end.
    sig { params(string: T.nilable(String)).void }
    def printt(string = nil)
      print(" " * @current_indent)
      print(string) if string
    end

    # Print a string with indentation and `\n` at the end.
    sig { params(string: String).void }
    def printl(string)
      printt
      printn(string)
    end
  end
end
