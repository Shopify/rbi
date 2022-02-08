# typed: strict
# frozen_string_literal: true

module RBI
  class Printer < Visitor
    extend T::Sig

    sig { returns(T::Boolean) }
    attr_accessor :print_locs, :in_visibility_group

    sig { returns(T.nilable(Node)) }
    attr_reader :previous_node

    sig { returns(Integer) }
    attr_reader :current_indent

    sig { returns(T.nilable(Integer)) }
    attr_reader :max_line_length

    sig do
      params(
        out: T.any(IO, StringIO),
        indent: Integer,
        print_locs: T::Boolean,
        max_line_length: T.nilable(Integer)
      ).void
    end
    def initialize(out: $stdout, indent: 0, print_locs: false, max_line_length: nil)
      super()
      @out = out
      @current_indent = indent
      @print_locs = print_locs
      @in_visibility_group = T.let(false, T::Boolean)
      @previous_node = T.let(nil, T.nilable(Node))
      @max_line_length = max_line_length
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

    sig { params(file: File).void }
    def visit_file(file)
      file.accept_printer(self)
    end

    sig { override.params(node: T.nilable(Node)).void }
    def visit(node)
      return unless node
      node.accept_printer(self)
    end

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
  end

  class File
    extend T::Sig

    sig { params(v: Printer).void }
    def accept_printer(v)
      strictness = self.strictness
      if strictness
        v.printl("# typed: #{strictness}")
      end
      unless comments.empty?
        v.printn if strictness
        v.visit_all(comments)
      end

      unless root.empty? && root.comments.empty?
        v.printn if strictness || !comments.empty?
        v.visit(root)
      end
    end

    sig do
      params(
        out: T.any(IO, StringIO),
        indent: Integer,
        print_locs: T::Boolean,
        max_line_length: T.nilable(Integer)
      ).void
    end
    def print(out: $stdout, indent: 0, print_locs: false, max_line_length: nil)
      p = Printer.new(out: out, indent: indent, print_locs: print_locs, max_line_length: max_line_length)
      p.visit_file(self)
    end

    sig { params(indent: Integer, print_locs: T::Boolean, max_line_length: T.nilable(Integer)).returns(String) }
    def string(indent: 0, print_locs: false, max_line_length: nil)
      out = StringIO.new
      print(out: out, indent: indent, print_locs: print_locs, max_line_length: max_line_length)
      out.string
    end
  end

  class Node
    extend T::Sig

    sig { abstract.params(v: Printer).void }
    def accept_printer(v); end

    sig do
      params(
        out: T.any(IO, StringIO),
        indent: Integer,
        print_locs: T::Boolean,
        max_line_length: T.nilable(Integer)
      ).void
    end
    def print(out: $stdout, indent: 0, print_locs: false, max_line_length: nil)
      p = Printer.new(out: out, indent: indent, print_locs: print_locs, max_line_length: max_line_length)
      p.visit(self)
    end

    sig { params(indent: Integer, print_locs: T::Boolean, max_line_length: T.nilable(Integer)).returns(String) }
    def string(indent: 0, print_locs: false, max_line_length: nil)
      out = StringIO.new
      print(out: out, indent: indent, print_locs: print_locs, max_line_length: max_line_length)
      out.string
    end

    sig { params(v: Printer).void }
    def print_blank_line_before(v)
      previous_node = v.previous_node
      return unless previous_node
      return if previous_node.is_a?(BlankLine)
      return if previous_node.oneline? && oneline?
      v.printn
    end

    sig { returns(T::Boolean) }
    def oneline?
      true
    end
  end

  class NodeWithComments
    extend T::Sig

    sig { override.returns(T::Boolean) }
    def oneline?
      comments.empty?
    end
  end

  class Comment
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      lines = text.lines

      if lines.empty?
        v.printl("#")
      end

      lines.each do |line|
        text = line.rstrip
        v.printt("#")
        v.print(" #{text}") unless text.empty?
        v.printn
      end
    end
  end

  class BlankLine
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.printn
    end
  end

  class Tree
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.visit_all(comments)
      v.printn if !comments.empty? && !empty?
      v.visit_all(nodes)
    end

    sig { override.returns(T::Boolean) }
    def oneline?
      comments.empty? && empty?
    end
  end

  class Scope
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      print_blank_line_before(v)

      v.printl("# #{loc}") if loc && v.print_locs
      v.visit_all(comments)

      print_header(v)
      print_body(v)
    end

    sig { abstract.params(v: Printer).void }
    def print_header(v); end

    sig { params(v: Printer).void }
    def print_body(v)
      unless empty?
        v.indent
        v.visit_all(nodes)
        v.dedent
        v.printl("end")
      end
    end
  end

  class Module
    extend T::Sig

    sig { override.params(v: Printer).void }
    def print_header(v)
      v.printt("module #{name}")
      if empty?
        v.printn("; end")
      else
        v.printn
      end
    end
  end

  class Class
    extend T::Sig

    sig { override.params(v: Printer).void }
    def print_header(v)
      v.printt("class #{name}")
      superclass = superclass_name
      v.print(" < #{superclass}") if superclass
      if empty?
        v.printn("; end")
      else
        v.printn
      end
    end
  end

  class Struct
    extend T::Sig

    sig { override.params(v: Printer).void }
    def print_header(v)
      v.printt("#{name} = ::Struct.new")
      if !members.empty? || keyword_init
        v.print("(")
        args = members.map { |member| ":#{member}" }
        args << "keyword_init: true" if keyword_init
        v.print(args.join(", "))
        v.print(")")
      end
      if empty?
        v.printn
      else
        v.printn(" do")
      end
    end
  end

  class SingletonClass
    extend T::Sig

    sig { override.params(v: Printer).void }
    def print_header(v)
      v.printt("class << self")
      if empty?
        v.printn("; end")
      else
        v.printn
      end
    end
  end

  class Const
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      print_blank_line_before(v)

      v.printl("# #{loc}") if loc && v.print_locs
      v.visit_all(comments)
      v.printl("#{name} = #{value}")
    end
  end

  class Attr
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      print_blank_line_before(v)

      v.visit_all(comments)
      sigs.each { |sig| v.visit(sig) }
      v.printl("# #{loc}") if loc && v.print_locs
      v.printt
      unless v.in_visibility_group || visibility.public?
        v.print(visibility.visibility.to_s)
        v.print(" ")
      end
      case self
      when AttrAccessor
        v.print("attr_accessor")
      when AttrReader
        v.print("attr_reader")
      when AttrWriter
        v.print("attr_writer")
      end
      unless names.empty?
        v.print(" ")
        v.print(names.map { |name| ":#{name}" }.join(", "))
      end
      v.printn
    end

    sig { override.returns(T::Boolean) }
    def oneline?
      comments.empty? && sigs.empty?
    end
  end

  class Method
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      print_blank_line_before(v)

      v.visit_all(comments)
      v.visit_all(sigs)
      v.printl("# #{loc}") if loc && v.print_locs
      v.printt
      unless v.in_visibility_group || visibility.public?
        v.print(visibility.visibility.to_s)
        v.print(" ")
      end
      v.print("def ")
      v.print("self.") if is_singleton
      v.print(name)
      unless params.empty?
        v.print("(")
        if inline_params?
          params.each_with_index do |param, index|
            v.print(", ") if index > 0
            v.visit(param)
          end
        else
          v.printn
          v.indent
          params.each_with_index do |param, pindex|
            v.printt
            v.visit(param)
            v.print(",") if pindex < params.size - 1

            param.comments_lines.each_with_index do |comment, cindex|
              if cindex > 0
                param.print_comment_leading_space(v, last: pindex == params.size - 1)
              else
                v.print(" ")
              end
              v.print("# #{comment}")
            end
            v.printn
          end
          v.dedent
        end
        v.print(")")
      end
      v.print("; end")
      v.printn
    end

    sig { override.returns(T::Boolean) }
    def oneline?
      comments.empty? && sigs.empty? && inline_params?
    end

    sig { returns(T::Boolean) }
    def inline_params?
      params.all? { |p| p.comments.empty? }
    end
  end

  class Param
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.print(name.to_s)
    end

    sig { params(v: Printer, last: T::Boolean).void }
    def print_comment_leading_space(v, last:)
      v.printn
      v.printt
      v.print(" " * (name.size + 1))
      v.print(" ") unless last
    end

    sig { returns(T::Array[String]) }
    def comments_lines
      comments.flat_map { |comment| comment.text.lines.map(&:rstrip) }
    end
  end

  class OptParam
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.print("#{name} = #{value}")
    end

    sig { override.params(v: Printer, last: T::Boolean).void }
    def print_comment_leading_space(v, last:)
      super
      v.print(" " * (value.size + 3))
    end
  end

  class RestParam
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.print("*#{name}")
    end

    sig { override.params(v: Printer, last: T::Boolean).void }
    def print_comment_leading_space(v, last:)
      super
      v.print(" ")
    end
  end

  class KwParam
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.print("#{name}:")
    end

    sig { override.params(v: Printer, last: T::Boolean).void }
    def print_comment_leading_space(v, last:)
      super
      v.print(" ")
    end
  end

  class KwOptParam
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.print("#{name}: #{value}")
    end

    sig { override.params(v: Printer, last: T::Boolean).void }
    def print_comment_leading_space(v, last:)
      super
      v.print(" " * (value.size + 2))
    end
  end

  class KwRestParam
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.print("**#{name}")
    end

    sig { override.params(v: Printer, last: T::Boolean).void }
    def print_comment_leading_space(v, last:)
      super
      v.print("  ")
    end
  end

  class BlockParam
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.print("&#{name}")
    end

    sig { override.params(v: Printer, last: T::Boolean).void }
    def print_comment_leading_space(v, last:)
      super
      v.print(" ")
    end
  end

  class Mixin
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      print_blank_line_before(v)

      v.printl("# #{loc}") if loc && v.print_locs
      v.visit_all(comments)
      case self
      when Include
        v.printt("include")
      when Extend
        v.printt("extend")
      when MixesInClassMethods
        v.printt("mixes_in_class_methods")
      end
      v.printn(" #{names.join(", ")}")
    end
  end

  class Visibility
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      print_blank_line_before(v)

      v.printl("# #{loc}") if loc && v.print_locs
      v.visit_all(comments)
      v.printl(visibility.to_s)
    end
  end

  class Send
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      print_blank_line_before(v)

      v.printl("# #{loc}") if loc && v.print_locs
      v.visit_all(comments)
      v.printt(method)
      unless args.empty?
        v.print(" ")
        args.each_with_index do |arg, index|
          v.visit(arg)
          v.print(", ") if index < args.size - 1
        end
      end
      v.printn
    end
  end

  class Arg
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.print(value)
    end
  end

  class KwArg
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.print(keyword)
      v.print(": ")
      v.print(value)
    end
  end

  class Sig
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.printl("# #{loc}") if loc && v.print_locs
      max_line_length = v.max_line_length
      if oneline? && max_line_length.nil?
        print_as_line(v)
      elsif max_line_length
        line = string(indent: v.current_indent)
        if line.length <= max_line_length
          v.print(line)
        else
          print_as_block(v)
        end
      else
        print_as_block(v)
      end
    end

    sig { override.returns(T::Boolean) }
    def oneline?
      inline_params?
    end

    sig { returns(T::Boolean) }
    def inline_params?
      params.all? { |p| p.comments.empty? }
    end

    private

    sig { returns(T::Array[String]) }
    def sig_modifiers
      modifiers = T.let([], T::Array[String])
      modifiers << "abstract" if is_abstract
      modifiers << "override" if is_override
      modifiers << "overridable" if is_overridable
      modifiers << "type_parameters(#{type_params.map { |type| ":#{type}" }.join(", ")})" if type_params.any?
      modifiers << "checked(:#{checked})" if checked
      modifiers
    end

    sig { params(v: Printer).void }
    def print_as_line(v)
      v.printt("sig")
      v.print("(:final)") if is_final
      v.print(" { ")
      sig_modifiers.each do |modifier|
        v.print("#{modifier}.")
      end
      unless params.empty?
        v.print("params(")
        params.each_with_index do |param, index|
          v.print(", ") if index > 0
          v.visit(param)
        end
        v.print(").")
      end
      if return_type && return_type != "void"
        v.print("returns(#{return_type})")
      else
        v.print("void")
      end
      v.printn(" }")
    end

    sig { params(v: Printer).void }
    def print_as_block(v)
      modifiers = sig_modifiers

      v.printl("sig do")
      v.indent
      if modifiers.any?
        v.printl(T.must(modifiers.first))
        v.indent
        modifiers[1..]&.each do |modifier|
          v.printl(".#{modifier}")
        end
      end

      if params.any?
        v.printt
        v.print(".") if modifiers.any?
        v.printn("params(")
        v.indent
        params.each_with_index do |param, pindex|
          v.printt
          v.visit(param)
          v.print(",") if pindex < params.size - 1
          param.comments_lines.each_with_index do |comment, cindex|
            if cindex == 0
              v.print(" ")
            else
              param.print_comment_leading_space(v, last: pindex == params.size - 1)
            end
            v.print("# #{comment}")
          end
          v.printn
        end
        v.dedent
        v.printt(")")
      end
      v.printt if params.empty?
      v.print(".") if modifiers.any? || params.any?
      if return_type && return_type != "void"
        v.print("returns(#{return_type})")
      else
        v.print("void")
      end
      v.printn
      v.dedent
      v.dedent if modifiers.any?
      v.printl("end")
    end
  end

  class SigParam
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.print("#{name}: #{type}")
    end

    sig { params(v: Printer, last: T::Boolean).void }
    def print_comment_leading_space(v, last:)
      v.printn
      v.printt
      v.print(" " * (name.size + type.size + 3))
      v.print(" ") unless last
    end

    sig { returns(T::Array[String]) }
    def comments_lines
      comments.flat_map { |comment| comment.text.lines.map(&:rstrip) }
    end
  end

  class TStructField
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      print_blank_line_before(v)

      v.printl("# #{loc}") if loc && v.print_locs
      v.visit_all(comments)
      case self
      when TStructProp
        v.printt("prop")
      when TStructConst
        v.printt("const")
      end
      v.print(" :#{name}, #{type}")
      default = self.default
      v.print(", default: #{default}") if default
      v.printn
    end
  end

  class TEnumBlock
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.printl("# #{loc}") if loc && v.print_locs
      v.visit_all(comments)
      v.printl("enums do")
      v.indent
      names.each do |name|
        v.printl("#{name} = new")
      end
      v.dedent
      v.printl("end")
    end
  end

  class TypeMember
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      print_blank_line_before(v)

      v.printl("# #{loc}") if loc && v.print_locs
      v.visit_all(comments)
      v.printl("#{name} = #{value}")
    end
  end

  class Helper
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      print_blank_line_before(v)

      v.printl("# #{loc}") if loc && v.print_locs
      v.visit_all(comments)
      v.printl("#{name}!")
    end
  end

  class Group
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.printn unless v.previous_node.nil?
      v.visit_all(nodes)
    end
  end

  class VisibilityGroup
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.in_visibility_group = true
      if visibility.public?
        v.printn unless v.previous_node.nil?
      else
        v.visit(visibility)
        v.printn
      end
      v.visit_all(nodes)
      v.in_visibility_group = false
    end

    sig { override.returns(T::Boolean) }
    def oneline?
      false
    end
  end

  class RequiresAncestor
    extend T::Sig

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      print_blank_line_before(v)

      v.printl("# #{loc}") if loc && v.print_locs
      v.visit_all(comments)
      v.printl("requires_ancestor { #{name} }")
    end
  end
end
