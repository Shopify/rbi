# typed: strict
# frozen_string_literal: true

module RBI
  class RBSPrinter < Visitor
    class Error < RBI::Error; end

    sig { returns(T::Boolean) }
    attr_accessor :print_locs, :in_visibility_group

    sig { returns(T.nilable(Node)) }
    attr_reader :previous_node

    sig { returns(Integer) }
    attr_reader :current_indent

    sig { params(out: T.any(IO, StringIO), indent: Integer, print_locs: T::Boolean).void }
    def initialize(out: $stdout, indent: 0, print_locs: false)
      super()
      @out = out
      @current_indent = indent
      @print_locs = print_locs
      @in_visibility_group = T.let(false, T::Boolean)
      @previous_node = T.let(nil, T.nilable(Node))
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
      unless file.comments.empty?
        visit_all(file.comments)
      end

      unless file.root.empty? && file.root.comments.empty?
        printn unless file.comments.empty?
        visit(file.root)
      end
    end

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
      node.nodes.grep(Helper).each do |helper|
        visit(Comment.new("@#{helper.name}"))
      end

      mixins = node.nodes.grep(MixesInClassMethods)
      if mixins.any?
        visit(Comment.new("@mixes_in_class_methods #{mixins.map(&:names).join(", ")}"))
      end

      ancestors = node.nodes.grep(RequiresAncestor)
      if ancestors.any?
        visit(Comment.new("@requires_ancestor #{ancestors.map(&:name).join(", ")}"))
      end

      case node
      when TStruct
        printt("class #{node.name}")
      when TEnum
        printt("class #{node.name}")
      when Module
        printt("module #{node.name}")
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
        raise Error, "Unhandled node: #{node.class}"
      end

      type_params = node.nodes.grep(TypeMember)
      if type_params.any?
        print("[#{type_params.map(&:name).join(", ")}]")
      end

      if !node.empty? && node.is_a?(Struct)
        print(" do")
      end
      printn
    end

    sig { params(node: Scope).void }
    def visit_scope_body(node)
      unless node.empty?
        indent
        visit_all(node.nodes)
        dedent
      end
      if !node.is_a?(Struct) || !node.empty?
        printl("end")
      end
    end

    sig { override.params(node: Const).void }
    def visit_const(node)
      print_blank_line_before(node)
      print_loc(node)
      visit_all(node.comments)

      type = parse_t_let(node.value)
      if type
        type = parse_type(type)
        printl("#{node.name}: #{type.rbs_string}")
      else
        printl("#{node.name}: untyped")
      end
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

      node.names.each do |name|
        visit_all(node.comments)
        print_loc(node)
        printt
        unless in_visibility_group || node.visibility.public? || node.visibility.protected?
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
        print(" #{name}")
        first_sig, *_rest = node.sigs # discard remaining signatures
        if first_sig
          print(": ")
          print_attr_sig(node, first_sig)
        else
          print(": untyped")
        end
        printn
      end
    end

    sig { params(node: RBI::Attr, sig: Sig).void }
    def print_attr_sig(node, sig)
      type = case node
      when AttrAccessor, AttrReader
        parse_type(sig.return_type)
      else
        first_arg = sig.params.first
        if first_arg
          parse_type(first_arg.type)
        else
          Type.untyped
        end
      end

      print(type.rbs_string)
    end

    sig { override.params(node: Method).void }
    def visit_method(node)
      print_blank_line_before(node)
      visit_all(node.comments)

      if node.sigs.any?(&:is_abstract)
        printl("# @abstract")
      end

      if node.sigs.any?(&:is_override)
        printl("# @override")
      end

      if node.sigs.any?(&:is_overridable)
        printl("# @overridable")
      end

      print_loc(node)
      printt
      unless in_visibility_group || node.visibility.public?
        self.print(node.visibility.visibility.to_s)
        print(" ")
      end
      print("def ")
      print("self.") if node.is_singleton
      print(node.name)
      sigs = node.sigs
      print(": ")
      if sigs.any?
        first, *rest = sigs
        print_method_sig(node, T.must(first))
        if rest.any?
          spaces = node.name.size + 4
          rest.each do |sig|
            printn
            printt
            print("#{" " * spaces}| ")
            print_method_sig(node, sig)
          end
        end
      else
        if node.params.any?
          params = node.params.reject { |param| param.is_a?(BlockParam) }
          block = node.params.find { |param| param.is_a?(BlockParam) }

          print("(")
          params.each_with_index do |param, index|
            print(", ") if index > 0
            visit(param)
          end
          print(") ")
          visit(block)
        end
        print("-> untyped")
      end
      printn
    end

    sig { params(node: RBI::Method, sig: Sig).void }
    def print_method_sig(node, sig)
      unless sig.type_params.empty?
        print("[#{sig.type_params.map { |t| "TYPE_#{t}" }.join(", ")}] ")
      end

      block_param = node.params.find { |param| param.is_a?(BlockParam) }
      sig_block_param = sig.params.find { |param| param.name == block_param&.name }

      sig_params = sig.params.dup
      if block_param
        sig_params.reject! do |param|
          param.name == block_param.name
        end
      end

      unless sig_params.empty?
        print("(")
        sig_params.each_with_index do |param, index|
          print(", ") if index > 0
          print_sig_param(node, param)
        end
        print(") ")
      end
      if sig_block_param
        block_type = sig_block_param.type
        block_type = Type.parse_string(block_type) if block_type.is_a?(String)

        block_is_nilable = false
        if block_type.is_a?(Type::Nilable)
          block_is_nilable = true
          block_type = block_type.type
        end

        type_string = parse_type(block_type).rbs_string.delete_prefix("^")

        skip = false
        case block_type
        when Type::Untyped
          type_string = "(?) -> untyped"
          block_is_nilable = true
        when Type::Simple
          if block_type.name == "Proc"
            type_string = "(?) -> untyped"
          end
          skip = true if block_type.name == "NilClass"
        end

        if skip
          # no-op, we skip the block definition
        elsif block_is_nilable
          print("?{ #{type_string} } ")
        else
          print("{ #{type_string} } ")
        end
      end

      type = parse_type(sig.return_type)
      print("-> #{type.rbs_string}")

      loc = sig.loc
      print(" # #{loc}") if loc && print_locs
    end

    sig { override.params(node: ReqParam).void }
    def visit_req_param(node)
      print("untyped #{node.name}")
    end

    sig { override.params(node: OptParam).void }
    def visit_opt_param(node)
      print("?untyped #{node.name}")
    end

    sig { override.params(node: RestParam).void }
    def visit_rest_param(node)
      print("*untyped #{node.name}")
    end

    sig { override.params(node: KwParam).void }
    def visit_kw_param(node)
      print("#{node.name}: untyped")
    end

    sig { override.params(node: KwOptParam).void }
    def visit_kw_opt_param(node)
      print("?#{node.name}: untyped")
    end

    sig { override.params(node: KwRestParam).void }
    def visit_kw_rest_param(node)
      print("**#{node.name}: untyped")
    end

    sig { override.params(node: BlockParam).void }
    def visit_block_param(node)
      print("{ (*untyped) -> untyped } ")
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
      return if node.is_a?(MixesInClassMethods) # no-op, `mixes_in_class_methods` is not supported in RBS

      print_blank_line_before(node)
      print_loc(node)
      visit_all(node.comments)

      case node
      when Include
        printt("include")
      when Extend
        printt("extend")
      end
      printn(" #{node.names.join(", ")}")
    end

    sig { override.params(node: Public).void }
    def visit_public(node)
      visit_visibility(node)
    end

    sig { override.params(node: Protected).void }
    def visit_protected(node)
      # no-op, `protected` is not supported in RBS
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
      # no-op, arbitrary sends are not supported in RBS
    end

    sig { override.params(node: Arg).void }
    def visit_arg(node)
      # no-op
    end

    sig { override.params(node: KwArg).void }
    def visit_kw_arg(node)
      # no-op
    end

    sig { override.params(node: TStruct).void }
    def visit_tstruct(node)
      print_blank_line_before(node)
      print_loc(node)
      visit_all(node.comments)

      visit_scope_header(node)
      nodes = node.nodes.dup

      sig = Sig.new
      init = Method.new("initialize", sigs: [sig])
      last_field = -1
      nodes.each_with_index do |child, i|
        case child
        when TStructField
          default = child.default
          init << if default
            KwOptParam.new(child.name, default)
          else
            KwParam.new(child.name)
          end
          sig << SigParam.new(child.name, child.type)
          last_field = i
        end
      end
      nodes.insert(last_field + 1, init)

      indent
      visit_all(nodes)
      dedent

      printl("end")
    end

    sig { override.params(node: TStructConst).void }
    def visit_tstruct_const(node)
      # `T::Struct.const` is not supported in RBS instead we generate an attribute reader
      accessor = AttrReader.new(node.name.to_sym, comments: node.comments, sigs: [Sig.new(return_type: node.type)])
      visit_attr_reader(accessor)
    end

    sig { override.params(node: TStructProp).void }
    def visit_tstruct_prop(node)
      # `T::Struct.prop` is not supported in RBS instead we generate an attribute accessor
      accessor = AttrAccessor.new(node.name.to_sym, comments: node.comments, sigs: [Sig.new(return_type: node.type)])
      visit_attr_accessor(accessor)
    end

    sig { override.params(node: TEnum).void }
    def visit_tenum(node)
      visit_scope(node)
    end

    sig { override.params(node: TEnumBlock).void }
    def visit_tenum_block(node)
      node.nodes.each do |child|
        child = if child.is_a?(Const) && child.value == "new"
          parent = node.parent_scope
          Const.new(
            child.name,
            "T.let(nil, #{parent.is_a?(TEnum) ? parent.name : "T.untyped"})",
            comments: child.comments,
          )
        else
          child
        end
        visit(child)
        @previous_node = child
      end
    end

    sig { override.params(node: TypeMember).void }
    def visit_type_member(node)
      # no-op, we already show them in the scope header
    end

    sig { override.params(node: Helper).void }
    def visit_helper(node)
      # no-op, we already show them in the scope header
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
      # no-op, we already show them in the scope header
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

    private

    sig { params(node: Node).void }
    def print_blank_line_before(node)
      previous_node = self.previous_node
      return unless previous_node
      return if previous_node.is_a?(BlankLine)
      return if previous_node.is_a?(TypeMember) # since we skip them
      return if previous_node.is_a?(Helper) # since we skip them
      return if previous_node.is_a?(Protected) # since we skip them
      return if previous_node.is_a?(RequiresAncestor) # since we skip them
      return if previous_node.is_a?(Send) # since we skip them
      return if previous_node.is_a?(Arg) # since we skip them
      return if previous_node.is_a?(KwArg) # since we skip them
      return if previous_node.is_a?(TEnumBlock) # since we skip them
      return if previous_node.is_a?(MixesInClassMethods) # since we skip them
      return if oneline?(previous_node) && oneline?(node)

      printn
    end

    sig { params(node: Node).void }
    def print_loc(node)
      loc = node.loc
      printl("# #{loc}") if loc && print_locs
    end

    sig { params(node: Method, param: SigParam).void }
    def print_sig_param(node, param)
      type = parse_type(param.type).rbs_string

      orig_param = node.params.find { |p| p.name == param.name }

      case orig_param
      when ReqParam
        print("#{type} #{param.name}")
      when OptParam
        print("?#{type} #{param.name}")
      when RestParam
        print("*#{type} #{param.name}")
      when KwParam
        print("#{param.name}: #{type}")
      when KwOptParam
        print("?#{param.name}: #{type}")
      when KwRestParam
        print("**#{type} #{param.name}")
      else
        raise Error, "Unexpected param type: #{orig_param.class} for param #{param.name}"
      end
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
        false
      when Attr
        node.comments.empty?
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

    sig { params(type: T.any(Type, String)).returns(Type) }
    def parse_type(type)
      return type if type.is_a?(Type)

      Type.parse_string(type)
    rescue Type::Error => e
      raise Error, "Failed to parse type `#{type}` (#{e.message})"
    end

    # Parse a string containing a `T.let(x, X)` and extract the type
    #
    # Returns `nil` is the string is not a `T.let`.
    sig { params(code: T.nilable(String)).returns(T.nilable(String)) }
    def parse_t_let(code)
      return unless code

      res = Prism.parse(code)
      return unless res.success?

      node = res.value
      return unless node.is_a?(Prism::ProgramNode)

      node = node.statements.body.first
      return unless node.is_a?(Prism::CallNode)
      return unless node.name == :let
      return unless node.receiver&.slice =~ /^(::)?T$/

      node.arguments&.arguments&.fetch(1, nil)&.slice
    end

    sig { params(node: Type).returns(T::Boolean) }
    def bare_proc?(node)
      node.is_a?(Type::Simple) && node.name == "Proc"
    end

    sig { params(node: Type).returns(T::Boolean) }
    def bare_nilable_proc?(node)
      node.is_a?(Type::Nilable) && bare_proc?(node.type)
    end
  end

  class TypePrinter
    extend T::Sig

    sig { returns(String) }
    attr_reader :string

    sig { void }
    def initialize
      @string = T.let(String.new, String)
    end

    sig { params(node: Type).void }
    def visit(node)
      case node
      when Type::Simple
        visit_simple(node)
      when Type::Boolean
        visit_boolean(node)
      when Type::Generic
        visit_generic(node)
      when Type::Anything
        visit_anything(node)
      when Type::Void
        visit_void(node)
      when Type::NoReturn
        visit_no_return(node)
      when Type::Untyped
        visit_untyped(node)
      when Type::SelfType
        visit_self_type(node)
      when Type::AttachedClass
        visit_attached_class(node)
      when Type::Nilable
        visit_nilable(node)
      when Type::ClassOf
        visit_class_of(node)
      when Type::All
        visit_all(node)
      when Type::Any
        visit_any(node)
      when Type::Tuple
        visit_tuple(node)
      when Type::Shape
        visit_shape(node)
      when Type::Proc
        visit_proc(node)
      when Type::TypeParameter
        visit_type_parameter(node)
      when Type::Class
        visit_class(node)
      else
        raise Error, "Unhandled node: #{node.class}"
      end
    end

    sig { params(type: Type::Simple).void }
    def visit_simple(type)
      @string << translate_t_type(type.name)
    end

    sig { params(type: Type::Boolean).void }
    def visit_boolean(type)
      @string << "bool"
    end

    sig { params(type: Type::Generic).void }
    def visit_generic(type)
      @string << translate_t_type(type.name)
      @string << "["
      type.params.each_with_index do |arg, index|
        visit(arg)
        @string << ", " if index < type.params.size - 1
      end
      @string << "]"
    end

    sig { params(type: Type::Anything).void }
    def visit_anything(type)
      @string << "top"
    end

    sig { params(type: Type::Void).void }
    def visit_void(type)
      @string << "void"
    end

    sig { params(type: Type::NoReturn).void }
    def visit_no_return(type)
      @string << "bot"
    end

    sig { params(type: Type::Untyped).void }
    def visit_untyped(type)
      @string << "untyped"
    end

    sig { params(type: Type::SelfType).void }
    def visit_self_type(type)
      @string << "self"
    end

    sig { params(type: Type::AttachedClass).void }
    def visit_attached_class(type)
      @string << "attached_class"
    end

    sig { params(type: Type::Nilable).void }
    def visit_nilable(type)
      visit(type.type)
      @string << "?"
    end

    sig { params(type: Type::ClassOf).void }
    def visit_class_of(type)
      @string << "singleton("
      visit(type.type)
      @string << ")"
    end

    sig { params(type: Type::All).void }
    def visit_all(type)
      @string << "("
      type.types.each_with_index do |arg, index|
        visit(arg)
        @string << " & " if index < type.types.size - 1
      end
      @string << ")"
    end

    sig { params(type: Type::Any).void }
    def visit_any(type)
      @string << "("
      type.types.each_with_index do |arg, index|
        visit(arg)
        @string << " | " if index < type.types.size - 1
      end
      @string << ")"
    end

    sig { params(type: Type::Tuple).void }
    def visit_tuple(type)
      @string << "["
      type.types.each_with_index do |arg, index|
        visit(arg)
        @string << ", " if index < type.types.size - 1
      end
      @string << "]"
    end

    sig { params(type: Type::Shape).void }
    def visit_shape(type)
      @string << "{"
      type.types.each_with_index do |(key, value), index|
        @string << "#{key}: "
        visit(value)
        @string << ", " if index < type.types.size - 1
      end
      @string << "}"
    end

    sig { params(type: Type::Proc).void }
    def visit_proc(type)
      @string << "^"
      if type.proc_params.any?
        @string << "("
        type.proc_params.each_with_index do |(key, value), index|
          visit(value)
          @string << " #{key}"
          @string << ", " if index < type.proc_params.size - 1
        end
        @string << ") "
      end
      @string << "-> "
      visit(type.proc_returns)
    end

    sig { params(type: Type::TypeParameter).void }
    def visit_type_parameter(type)
      @string << "TYPE_#{type.name}"
    end

    sig { params(type: Type::Class).void }
    def visit_class(type)
      @string << "singleton("
      visit(type.type)
      @string << ")"
    end

    private

    sig { params(type_name: String).returns(String) }
    def translate_t_type(type_name)
      case type_name
      when "T::Array"
        "Array"
      when "T::Hash"
        "Hash"
      when "T::Set"
        "Set"
      else
        type_name
      end
    end
  end

  class File
    extend T::Sig

    sig { params(out: T.any(IO, StringIO), indent: Integer, print_locs: T::Boolean).void }
    def rbs_print(out: $stdout, indent: 0, print_locs: false)
      p = RBSPrinter.new(out: out, indent: indent, print_locs: print_locs)
      p.visit_file(self)
    end

    sig { params(indent: Integer, print_locs: T::Boolean).returns(String) }
    def rbs_string(indent: 0, print_locs: false)
      out = StringIO.new
      rbs_print(out: out, indent: indent, print_locs: print_locs)
      out.string
    end
  end

  class Node
    extend T::Sig

    sig { params(out: T.any(IO, StringIO), indent: Integer, print_locs: T::Boolean).void }
    def rbs_print(out: $stdout, indent: 0, print_locs: false)
      p = RBSPrinter.new(out: out, indent: indent, print_locs: print_locs)
      p.visit(self)
    end

    sig { params(indent: Integer, print_locs: T::Boolean).returns(String) }
    def rbs_string(indent: 0, print_locs: false)
      out = StringIO.new
      rbs_print(out: out, indent: indent, print_locs: print_locs)
      out.string
    end
  end

  class Type
    extend T::Sig

    sig { returns(String) }
    def rbs_string
      p = TypePrinter.new
      p.visit(self)
      p.string
    end
  end
end
