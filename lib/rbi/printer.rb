# typed: strict
# frozen_string_literal: true

module RBI
  class Printer < Visitor
    extend T::Sig

    sig { params(out: T.any(IO, StringIO)).void }
    def initialize(out: $stdout)
      @out = out
      @current_indent = T.let(0, Integer)
    end

    # Printing

    sig { void }
    def indent
      @current_indent += 2
    end

    sig { void }
    def dedent
      @current_indent -= 2
    end

    sig { params(string: String).void }
    def print(string)
      @out.print(string)
    end

    sig { params(string: T.nilable(String)).void }
    def printn(string = nil)
      print(string) if string
      print("\n")
    end

    sig { params(string: T.nilable(String)).void }
    def printt(string = nil)
      print(" " * @current_indent)
      print(string) if string
    end

    sig { params(string: String).void }
    def printl(string)
      printt
      printn(string)
    end

    sig { override.params(node: T.nilable(Node)).void }
    def visit(node)
      return unless node
      node.accept_printer(self)
    end
  end

  class Node
    extend T::Sig

    sig { abstract.params(v: Printer).void }
    def accept_printer(v); end

    sig { params(out: T.any(IO, StringIO)).void }
    def print(out: $stdout)
      p = Printer.new(out: out)
      p.visit(self)
    end
  end

  class Tree
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.visit_all(nodes)
    end
  end

  class Scope
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      case self
      when Module
        v.printt("module #{name}")
      when Class
        v.printt("class #{name}")
        superclass = superclass_name
        v.print(" < #{superclass}") if superclass
      when SClass
        v.printt("class << self")
      end
      if nodes.empty?
        v.printn("; end")
      else
        v.printn
        v.indent
        v.visit_all(nodes)
        v.dedent
        v.printl("end")
      end
    end
  end
end