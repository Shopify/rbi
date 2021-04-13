# typed: strict
# frozen_string_literal: true

module RBI
  class Printer < Visitor
    extend T::Sig

    sig { returns(T::Boolean) }
    attr_reader :show_locs

    sig { params(out: T.any(IO, StringIO), show_locs: T::Boolean).void }
    def initialize(out: $stdout, show_locs: false)
      super()
      @out = out
      @current_indent = T.let(0, Integer)
      @show_locs = show_locs
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

    sig { params(out: T.any(IO, StringIO), show_locs: T::Boolean).void }
    def print(out: $stdout, show_locs: false)
      p = Printer.new(out: out, show_locs: show_locs)
      p.visit(self)
    end
  end

  class Comment
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.printl(text.strip)
    end
  end

  class Tree
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.visit_all(comments)
      v.visit_all(nodes)
    end
  end

  class Scope
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.visit_all(comments)
      v.printl("# #{loc}") if loc && v.show_locs
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

  class Const
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.visit_all(comments)
      v.printt("#{name} = _")
      v.print(" # #{loc}") if loc && v.show_locs
      v.printn
    end
  end

  class Method
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.visit_all(comments)
      v.printt("def ")
      v.print("self.") if is_singleton
      v.print(name.to_s)
      unless params.empty?
        can_inline = params.reject { |p| p.comments.empty? }.empty?
        if can_inline
          v.print("(")
          params.each_with_index do |param, index|
            v.print(", ") if index > 0
            v.visit(param)
          end
        else
          v.printn("(")
          v.indent
          params.each_with_index do |param, pindex|
            v.printt
            v.visit(param)
            v.print(", ") if pindex < params.size - 1
            param.comments.each_with_index do |comment, cindex|
              if cindex > 0
                size = comment.text.length - 1
                text = comment.text[1..size] || ""
                v.print(", ")
                v.print(text.strip)
              else
                v.print(comment.text.strip)
              end
            end
            v.printn
          end
          v.dedent
        end
        v.print(")")
      end
      v.print("; end")
      v.print(" # #{loc}") if loc && v.show_locs
      v.printn
    end
  end

  class Param
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      if is_block
        v.print("&#{name}")
      elsif is_keyword
        if is_optional
          v.print("#{name}: _")
        elsif is_rest
          v.print("**#{name}")
        else
          v.print("#{name}:")
        end
      elsif is_optional
        v.print("#{name} = _")
      elsif is_rest
        v.print("*#{name}")
      else
        v.print(name.to_s)
      end
    end
  end

  class Send
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.visit_all(comments)
      v.printt(method.to_s)
      unless args.empty?
        v.print("(")
        v.print(args.map { |arg| arg }.join(", "))
        v.print(")")
      end
      v.print(" # #{loc}") if loc && v.show_locs
      v.printn
    end
  end
end
