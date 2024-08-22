# typed: strict
# frozen_string_literal: true

module RBI
  class PrinterError < Error; end

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
        max_line_length: T.nilable(Integer),
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

    sig { override.params(file: File).void }
    def visit_file(file)
      strictness = file.strictness
      if strictness
        printl("# typed: #{strictness}")
      end
      unless file.comments.empty?
        printn if strictness
        visit_all(file.comments)
      end

      unless file.root.empty? && file.root.comments.empty?
        printn if strictness || !file.comments.empty?
        visit(file.root)
      end
    end

    private

    sig { override.params(node: Comment).void }
    def visit_comment(node)
      lines = node.text.lines

      if lines.empty?
        printl("#")
      end

      lines.each do |line|
        text = line.rstrip
        printt("#")
        print(" #{text}") unless text.empty?
        printn
      end
    end

    sig { override.params(node: BlankLine).void }
    def visit_blank_line(node)
      printn
    end

    sig { override.params(node: Tree).void }
    def visit_tree(node)
      visit_all(node.comments)
      printn if !node.comments.empty? && !node.empty?
      visit_all(node.nodes)
    end

    sig { override.params(node: Module).void }
    def visit_module(node)
      visit_scope(node)
    end

    sig { override.params(node: Class).void }
    def visit_class(node)
      visit_scope(node)
    end

    sig { override.params(node: Struct).void }
    def visit_struct(node)
      visit_scope(node)
    end

    sig { override.params(node: SingletonClass).void }
    def visit_singleton_class(node)
      visit_scope(node)
    end

    sig { params(node: Scope).void }
    def visit_scope(node)
      print_blank_line_before(node)
      print_loc(node)
      visit_all(node.comments)

      visit_scope_header(node)
      visit_scope_body(node)
    end

    sig { params(node: Scope).void }
    def visit_scope_header(node)
      case node
      when Module
        printt("module #{node.name}")
      when TEnum
        printt("class #{node.name} < T::Enum")
      when TStruct
        printt("class #{node.name} < T::Struct")
      when Class
        printt("class #{node.name}")
        superclass = node.superclass_name
        print(" < #{superclass}") if superclass
      when Struct
        printt("#{node.name} = ::Struct.new")
        if !node.members.empty? || node.keyword_init
          print("(")
          args = node.members.map { |member| ":#{member}" }
          args << "keyword_init: true" if node.keyword_init
          print(args.join(", "))
          print(")")
        end
      when SingletonClass
        printt("class << self")
      else
        raise PrinterError, "Unhandled node: #{node.class}"
      end
      if node.empty? && !node.is_a?(Struct)
        print("; end")
      elsif !node.empty? && node.is_a?(Struct)
        print(" do")
      end
      printn
    end

    sig { params(node: Scope).void }
    def visit_scope_body(node)
      return if node.empty?

      indent
      visit_all(node.nodes)
      dedent
      printl("end")
    end

    sig { override.params(node: Const).void }
    def visit_const(node)
      print_blank_line_before(node)
      print_loc(node)
      visit_all(node.comments)

      printl("#{node.name} = #{node.value}")
    end

    sig { override.params(node: AttrAccessor).void }
    def visit_attr_accessor(node)
      visit_attr(node)
    end

    sig { override.params(node: AttrReader).void }
    def visit_attr_reader(node)
      visit_attr(node)
    end

    sig { override.params(node: AttrWriter).void }
    def visit_attr_writer(node)
      visit_attr(node)
    end

    sig { params(node: Attr).void }
    def visit_attr(node)
      print_blank_line_before(node)

      visit_all(node.comments)
      node.sigs.each { |sig| visit(sig) }

      print_loc(node)
      printt
      unless in_visibility_group || node.visibility.public?
        self.print(node.visibility.visibility.to_s)
        print(" ")
      end
      case node
      when AttrAccessor
        print("attr_accessor")
      when AttrReader
        print("attr_reader")
      when AttrWriter
        print("attr_writer")
      end
      unless node.names.empty?
        print(" ")
        print(node.names.map { |name| ":#{name}" }.join(", "))
      end
      printn
    end

    sig { override.params(node: Method).void }
    def visit_method(node)
      print_blank_line_before(node)
      visit_all(node.comments)
      visit_all(node.sigs)

      print_loc(node)
      printt
      unless in_visibility_group || node.visibility.public?
        self.print(node.visibility.visibility.to_s)
        print(" ")
      end
      print("def ")
      print("self.") if node.is_singleton
      print(node.name)
      unless node.params.empty?
        print("(")
        if node.params.all? { |p| p.comments.empty? }
          node.params.each_with_index do |param, index|
            print(", ") if index > 0
            visit(param)
          end
        else
          printn
          indent
          node.params.each_with_index do |param, pindex|
            printt
            visit(param)
            print(",") if pindex < node.params.size - 1

            comment_lines = param.comments.flat_map { |comment| comment.text.lines.map(&:rstrip) }
            comment_lines.each_with_index do |comment, cindex|
              if cindex > 0
                print_param_comment_leading_space(param, last: pindex == node.params.size - 1)
              else
                print(" ")
              end
              print("# #{comment}")
            end
            printn
          end
          dedent
        end
        print(")")
      end
      print("; end")
      printn
    end

    sig { override.params(node: ReqParam).void }
    def visit_req_param(node)
      print(node.name)
    end

    sig { override.params(node: OptParam).void }
    def visit_opt_param(node)
      print("#{node.name} = #{node.value}")
    end

    sig { override.params(node: RestParam).void }
    def visit_rest_param(node)
      print("*#{node.name}")
    end

    sig { override.params(node: KwParam).void }
    def visit_kw_param(node)
      print("#{node.name}:")
    end

    sig { override.params(node: KwOptParam).void }
    def visit_kw_opt_param(node)
      print("#{node.name}: #{node.value}")
    end

    sig { override.params(node: KwRestParam).void }
    def visit_kw_rest_param(node)
      print("**#{node.name}")
    end

    sig { override.params(node: BlockParam).void }
    def visit_block_param(node)
      print("&#{node.name}")
    end

    sig { override.params(node: Include).void }
    def visit_include(node)
      visit_mixin(node)
    end

    sig { override.params(node: Extend).void }
    def visit_extend(node)
      visit_mixin(node)
    end

    sig { params(node: Mixin).void }
    def visit_mixin(node)
      print_blank_line_before(node)
      print_loc(node)
      visit_all(node.comments)

      case node
      when Include
        printt("include")
      when Extend
        printt("extend")
      when MixesInClassMethods
        printt("mixes_in_class_methods")
      end
      printn(" #{node.names.join(", ")}")
    end

    sig { override.params(node: Public).void }
    def visit_public(node)
      visit_visibility(node)
    end

    sig { override.params(node: Protected).void }
    def visit_protected(node)
      visit_visibility(node)
    end

    sig { override.params(node: Private).void }
    def visit_private(node)
      visit_visibility(node)
    end

    sig { params(node: Visibility).void }
    def visit_visibility(node)
      print_blank_line_before(node)
      print_loc(node)
      visit_all(node.comments)

      printl(node.visibility.to_s)
    end

    sig { override.params(node: Send).void }
    def visit_send(node)
      print_blank_line_before(node)
      print_loc(node)
      visit_all(node.comments)

      printt(node.method)
      unless node.args.empty?
        print(" ")
        node.args.each_with_index do |arg, index|
          visit(arg)
          print(", ") if index < node.args.size - 1
        end
      end
      printn
    end

    sig { override.params(node: Arg).void }
    def visit_arg(node)
      print(node.value)
    end

    sig { override.params(node: KwArg).void }
    def visit_kw_arg(node)
      print("#{node.keyword}: #{node.value}")
    end

    sig { override.params(node: Sig).void }
    def visit_sig(node)
      print_loc(node)
      visit_all(node.comments)

      max_line_length = self.max_line_length
      if oneline?(node) && max_line_length.nil?
        print_sig_as_line(node)
      elsif max_line_length
        line = node.string(indent: current_indent)
        if line.length <= max_line_length
          print(line)
        else
          print_sig_as_block(node)
        end
      else
        print_sig_as_block(node)
      end
    end

    sig { override.params(node: SigParam).void }
    def visit_sig_param(node)
      print("#{node.name}: #{node.type}")
    end

    sig { override.params(node: TStruct).void }
    def visit_tstruct(node)
      visit_scope(node)
    end

    sig { override.params(node: TStructConst).void }
    def visit_tstruct_const(node)
      visit_t_struct_field(node)
    end

    sig { override.params(node: TStructProp).void }
    def visit_tstruct_prop(node)
      visit_t_struct_field(node)
    end

    sig { params(node: TStructField).void }
    def visit_t_struct_field(node)
      print_blank_line_before(node)
      print_loc(node)
      visit_all(node.comments)

      case node
      when TStructProp
        printt("prop")
      when TStructConst
        printt("const")
      end
      print(" :#{node.name}, #{node.type}")
      default = node.default
      print(", default: #{default}") if default
      printn
    end

    sig { override.params(node: TEnum).void }
    def visit_tenum(node)
      visit_scope(node)
    end

    sig { override.params(node: TEnumBlock).void }
    def visit_tenum_block(node)
      print_loc(node)
      visit_all(node.comments)

      printl("enums do")
      indent
      visit_all(node.nodes)
      dedent
      printl("end")
    end

    sig { override.params(node: TypeMember).void }
    def visit_type_member(node)
      print_blank_line_before(node)
      print_loc(node)
      visit_all(node.comments)

      printl("#{node.name} = #{node.value}")
    end

    sig { override.params(node: Helper).void }
    def visit_helper(node)
      print_blank_line_before(node)
      print_loc(node)
      visit_all(node.comments)

      printl("#{node.name}!")
    end

    sig { override.params(node: MixesInClassMethods).void }
    def visit_mixes_in_class_methods(node)
      visit_mixin(node)
    end

    sig { override.params(node: Group).void }
    def visit_group(node)
      printn unless previous_node.nil?
      visit_all(node.nodes)
    end

    sig { override.params(node: VisibilityGroup).void }
    def visit_visibility_group(node)
      self.in_visibility_group = true
      if node.visibility.public?
        printn unless previous_node.nil?
      else
        visit(node.visibility)
        printn
      end
      visit_all(node.nodes)
      self.in_visibility_group = false
    end

    sig { override.params(node: RequiresAncestor).void }
    def visit_requires_ancestor(node)
      print_blank_line_before(node)
      print_loc(node)
      visit_all(node.comments)

      printl("requires_ancestor { #{node.name} }")
    end

    sig { override.params(node: ConflictTree).void }
    def visit_conflict_tree(node)
      printl("<<<<<<< #{node.left_name}")
      visit(node.left)
      printl("=======")
      visit(node.right)
      printl(">>>>>>> #{node.right_name}")
    end

    sig { override.params(node: ScopeConflict).void }
    def visit_scope_conflict(node)
      print_blank_line_before(node)
      print_loc(node)
      visit_all(node.comments)

      printl("<<<<<<< #{node.left_name}")
      visit_scope_header(node.left)
      printl("=======")
      visit_scope_header(node.right)
      printl(">>>>>>> #{node.right_name}")
      visit_scope_body(node.left)
    end

    sig { params(node: Node).void }
    def print_blank_line_before(node)
      previous_node = self.previous_node
      return unless previous_node
      return if previous_node.is_a?(BlankLine)
      return if oneline?(previous_node) && oneline?(node)

      printn
    end

    sig { params(node: Node).void }
    def print_loc(node)
      loc = node.loc
      printl("# #{loc}") if loc && print_locs
    end

    sig { params(node: Param, last: T::Boolean).void }
    def print_param_comment_leading_space(node, last:)
      printn
      printt
      print(" " * (node.name.size + 1))
      print(" ") unless last
      case node
      when OptParam
        print(" " * (node.value.size + 3))
      when RestParam, KwParam, BlockParam
        print(" ")
      when KwRestParam
        print("  ")
      when KwOptParam
        print(" " * (node.value.size + 2))
      end
    end

    sig { params(node: SigParam, last: T::Boolean).void }
    def print_sig_param_comment_leading_space(node, last:)
      printn
      printt
      print(" " * (node.name.size + node.type.to_s.size + 3))
      print(" ") unless last
    end

    sig { params(node: Node).returns(T::Boolean) }
    def oneline?(node)
      case node
      when ScopeConflict
        oneline?(node.left)
      when Tree
        node.comments.empty? && node.empty?
      when Attr
        node.comments.empty? && node.sigs.empty?
      when Method
        node.comments.empty? && node.sigs.empty? && node.params.all? { |p| p.comments.empty? }
      when Sig
        node.params.all? { |p| p.comments.empty? }
      when NodeWithComments
        node.comments.empty?
      when VisibilityGroup
        false
      else
        true
      end
    end

    sig { params(node: Sig).void }
    def print_sig_as_line(node)
      printt("sig")
      print("(:final)") if node.is_final
      print(" { ")
      sig_modifiers(node).each do |modifier|
        print("#{modifier}.")
      end
      unless node.params.empty?
        print("params(")
        node.params.each_with_index do |param, index|
          print(", ") if index > 0
          visit(param)
        end
        print(").")
      end
      return_type = node.return_type
      if node.return_type.to_s == "void"
        print("void")
      else
        print("returns(#{return_type})")
      end
      printn(" }")
    end

    sig { params(node: Sig).void }
    def print_sig_as_block(node)
      modifiers = sig_modifiers(node)

      printt("sig")
      print("(:final)") if node.is_final
      printn(" do")
      indent
      if modifiers.any?
        printl(T.must(modifiers.first))
        indent
        modifiers[1..]&.each do |modifier|
          printl(".#{modifier}")
        end
      end

      params = node.params
      if params.any?
        printt
        print(".") if modifiers.any?
        printn("params(")
        indent
        params.each_with_index do |param, pindex|
          printt
          visit(param)
          print(",") if pindex < params.size - 1

          comment_lines = param.comments.flat_map { |comment| comment.text.lines.map(&:rstrip) }
          comment_lines.each_with_index do |comment, cindex|
            if cindex == 0
              print(" ")
            else
              print_sig_param_comment_leading_space(param, last: pindex == params.size - 1)
            end
            print("# #{comment}")
          end
          printn
        end
        dedent
        printt(")")
      end
      printt if params.empty?
      print(".") if modifiers.any? || params.any?

      return_type = node.return_type
      if return_type.to_s == "void"
        print("void")
      else
        print("returns(#{return_type})")
      end
      printn
      dedent
      dedent if modifiers.any?
      printl("end")
    end

    sig { params(node: Sig).returns(T::Array[String]) }
    def sig_modifiers(node)
      modifiers = T.let([], T::Array[String])
      modifiers << "abstract" if node.is_abstract
      modifiers << "override" if node.is_override
      modifiers << "overridable" if node.is_overridable
      modifiers << "type_parameters(#{node.type_params.map { |type| ":#{type}" }.join(", ")})" if node.type_params.any?
      modifiers << "checked(:#{node.checked})" if node.checked
      modifiers
    end
  end

  class File
    extend T::Sig

    sig do
      params(
        out: T.any(IO, StringIO),
        indent: Integer,
        print_locs: T::Boolean,
        max_line_length: T.nilable(Integer),
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

    sig do
      params(
        out: T.any(IO, StringIO),
        indent: Integer,
        print_locs: T::Boolean,
        max_line_length: T.nilable(Integer),
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
  end
end
