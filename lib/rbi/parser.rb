# typed: strict
# frozen_string_literal: true

require "yarp"

module RBI
  class ParseError < StandardError
    extend T::Sig

    sig { returns(Loc) }
    attr_reader :location

    sig { params(message: String, location: Loc).void }
    def initialize(message, location)
      super(message)
      @location = location
    end
  end

  class UnexpectedParserError < StandardError
    extend T::Sig

    sig { returns(Loc) }
    attr_reader :last_location

    sig { params(parent_exception: Exception, last_location: Loc).void }
    def initialize(parent_exception, last_location)
      super(parent_exception)
      set_backtrace(parent_exception.backtrace)
      @last_location = last_location
    end

    sig { params(io: T.any(IO, StringIO)).void }
    def print_debug(io: $stderr)
      io.puts ""
      io.puts "##################################"
      io.puts "### RBI::Parser internal error ###"
      io.puts "##################################"
      io.puts ""
      io.puts "There was an internal parser error while processing this source."
      io.puts ""
      io.puts "Error: #{message} while parsing #{last_location}:"
      io.puts ""
      io.puts last_location.source || "<no source>"
      io.puts ""
      io.puts "Please open an issue at https://github.com/Shopify/rbi/issues/new."
      io.puts ""
      io.puts "##################################"
      io.puts ""
    end
  end

  class Parser
    extend T::Sig

    class << self
      extend T::Sig

      sig { params(string: String).returns(Tree) }
      def parse_string(string)
        Parser.new.parse_string(string)
      end

      sig { params(path: String).returns(Tree) }
      def parse_file(path)
        Parser.new.parse_file(path)
      end

      sig { params(paths: T::Array[String]).returns(T::Array[Tree]) }
      def parse_files(paths)
        parser = Parser.new
        paths.map { |path| parser.parse_file(path) }
      end

      sig { params(strings: T::Array[String]).returns(T::Array[Tree]) }
      def parse_strings(strings)
        parser = Parser.new
        strings.map { |string| parser.parse_string(string) }
      end
    end

    sig { params(string: String).returns(Tree) }
    def parse_string(string)
      parse(string, file: "-")
    end

    sig { params(path: String).returns(Tree) }
    def parse_file(path)
      parse(::File.read(path), file: path)
    end

    private

    sig { params(source: String, file: String).returns(Tree) }
    def parse(source, file:)
      result = YARP.parse(source)
      unless result.success?
        message = result.errors.map { |e| "#{e.message}." }.join(" ")
        error = T.must(result.errors.first)
        location = Loc.new(file: file, begin_line: error.location.start_line, begin_column: error.location.start_column)
        raise ParseError.new(message, location)
      end

      visitor = TreeBuilder.new(source, comments: result.comments, file: file)
      visitor.visit(result.value)
      visitor.tree
    rescue YARP::ParseError => e
      raise ParseError.new(e.message, Loc.from_yarp(file, e.location))
    rescue ParseError => e
      raise e
    rescue => e
      last_node = visitor&.last_node
      last_location = if last_node
        Loc.from_yarp(file, last_node.location)
      else
        Loc.new(file: file)
      end

      exception = UnexpectedParserError.new(e, last_location)
      exception.print_debug
      raise exception
    end

    class Visitor < YARP::Visitor
      extend T::Sig

      sig { params(source: String, file: String).void }
      def initialize(source, file:)
        super()

        @source = source
        @file = file
      end

      private

      sig { params(node: YARP::Node).returns(Loc) }
      def node_loc(node)
        Loc.from_yarp(@file, node.location)
      end

      sig { params(node: T.nilable(YARP::Node)).returns(T.nilable(String)) }
      def node_string(node)
        return unless node

        node.slice
      end

      sig { params(node: YARP::Node).returns(String) }
      def node_string!(node)
        T.must(node_string(node))
      end
    end

    class TreeBuilder < Visitor
      extend T::Sig

      sig { returns(Tree) }
      attr_reader :tree

      sig { returns(T.nilable(YARP::Node)) }
      attr_reader :last_node

      sig { params(source: String, comments: T::Array[YARP::Comment], file: String).void }
      def initialize(source, comments:, file:)
        super(source, file: file)

        @comments_by_line = T.let(comments.to_h { |c| [c.location.start_line, c] }, T::Hash[Integer, YARP::Comment])
        @tree = T.let(Tree.new, Tree)

        @scopes_stack = T.let([@tree], T::Array[Tree])
        @last_node = T.let(nil, T.nilable(YARP::Node))
        @last_sigs = T.let([], T::Array[RBI::Sig])
        @last_sigs_comments = T.let([], T::Array[Comment])
      end

      sig { override.params(node: T.nilable(YARP::Node)).void }
      def visit(node)
        return unless node

        @last_node = node
        super
      end

      sig { override.params(node: YARP::ClassNode).void }
      def visit_class_node(node)
        scope = Class.new(
          node_string!(node.constant_path),
          superclass_name: node_string(node.superclass),
          loc: node_loc(node),
          comments: node_comments(node),
        )

        current_scope << scope
        @scopes_stack << scope
        visit(node.body)
        collect_dangling_comments(node)
        @scopes_stack.pop
      end

      sig { override.params(node: YARP::ConstantWriteNode).void }
      def visit_constant_write_node(node)
        visit_constant_assign(node)
      end

      sig { override.params(node: YARP::ConstantPathWriteNode).void }
      def visit_constant_path_write_node(node)
        visit_constant_assign(node)
      end

      sig { params(node: T.any(YARP::ConstantWriteNode, YARP::ConstantPathWriteNode)).void }
      def visit_constant_assign(node)
        struct = parse_struct(node)

        current_scope << if struct
          struct
        elsif type_variable_definition?(node.value)
          TypeMember.new(
            case node
            when YARP::ConstantWriteNode
              node.name.to_s
            when YARP::ConstantPathWriteNode
              node_string!(node.target)
            end,
            node_string!(node.value),
            loc: node_loc(node),
            comments: node_comments(node),
          )
        else
          Const.new(
            case node
            when YARP::ConstantWriteNode
              node.name.to_s
            when YARP::ConstantPathWriteNode
              node_string!(node.target)
            end,
            node_string!(node.value),
            loc: node_loc(node),
            comments: node_comments(node),
          )
        end
      end

      sig { override.params(node: YARP::DefNode).void }
      def visit_def_node(node)
        current_scope << Method.new(
          node.name.to_s,
          params: parse_params(node.parameters),
          sigs: current_sigs,
          loc: node_loc(node),
          comments: current_sigs_comments + node_comments(node),
          is_singleton: !!node.receiver,
        )
      end

      sig { override.params(node: YARP::ModuleNode).void }
      def visit_module_node(node)
        scope = Module.new(
          node_string!(node.constant_path),
          loc: node_loc(node),
          comments: node_comments(node),
        )

        current_scope << scope
        @scopes_stack << scope
        visit(node.body)
        collect_dangling_comments(node)
        @scopes_stack.pop
      end

      sig { override.params(node: YARP::ProgramNode).void }
      def visit_program_node(node)
        super

        collect_orphan_comments
        separate_header_comments
        set_root_tree_loc
      end

      sig { override.params(node: YARP::SingletonClassNode).void }
      def visit_singleton_class_node(node)
        scope = SingletonClass.new(
          loc: node_loc(node),
          comments: node_comments(node),
        )

        current_scope << scope
        @scopes_stack << scope
        visit(node.body)
        collect_dangling_comments(node)
        @scopes_stack.pop
      end

      sig { params(node: YARP::CallNode).void }
      def visit_call_node(node)
        message = node.name
        case message
        when "abstract!", "sealed!", "interface!"
          current_scope << Helper.new(
            message.delete_suffix("!"),
            loc: node_loc(node),
            comments: node_comments(node),
          )
        when "attr_reader"
          args = node.arguments
          return unless args.is_a?(YARP::ArgumentsNode) && args.arguments.any?

          current_scope << AttrReader.new(
            *T.unsafe(args.arguments.map { |arg| node_string!(arg).delete_prefix(":").to_sym }),
            sigs: current_sigs,
            loc: node_loc(node),
            comments: current_sigs_comments + node_comments(node),
          )
        when "attr_writer"
          args = node.arguments
          return unless args.is_a?(YARP::ArgumentsNode) && args.arguments.any?

          current_scope << AttrWriter.new(
            *T.unsafe(args.arguments.map { |arg| node_string!(arg).delete_prefix(":").to_sym }),
            sigs: current_sigs,
            loc: node_loc(node),
            comments: current_sigs_comments + node_comments(node),
          )
        when "attr_accessor"
          args = node.arguments
          return unless args.is_a?(YARP::ArgumentsNode) && args.arguments.any?

          current_scope << AttrAccessor.new(
            *T.unsafe(args.arguments.map { |arg| node_string!(arg).delete_prefix(":").to_sym }),
            sigs: current_sigs,
            loc: node_loc(node),
            comments: current_sigs_comments + node_comments(node),
          )
        when "enums"
          block = node.block
          return unless block.is_a?(YARP::BlockNode)

          body = block.body
          return unless body.is_a?(YARP::StatementsNode)

          current_scope << TEnumBlock.new(
            body.body.map { |stmt| T.cast(stmt, YARP::ConstantWriteNode).name.to_s },
            loc: node_loc(node),
            comments: node_comments(node),
          )
        when "extend"
          args = node.arguments
          return unless args.is_a?(YARP::ArgumentsNode) && args.arguments.any?

          current_scope << Extend.new(
            *T.unsafe(args.arguments.map { |arg| node_string!(arg) }),
            loc: node_loc(node),
            comments: node_comments(node),
          )
        when "include"
          args = node.arguments
          return unless args.is_a?(YARP::ArgumentsNode) && args.arguments.any?

          current_scope << Include.new(
            *T.unsafe(args.arguments.map { |arg| node_string!(arg) }),
            loc: node_loc(node),
            comments: node_comments(node),
          )
        when "mixes_in_class_methods"
          args = node.arguments
          return unless args.is_a?(YARP::ArgumentsNode) && args.arguments.any?

          current_scope << MixesInClassMethods.new(
            *T.unsafe(args.arguments.map { |arg| node_string!(arg) }),
            loc: node_loc(node),
            comments: node_comments(node),
          )
        when "private", "protected", "public"
          args = node.arguments
          if args.is_a?(YARP::ArgumentsNode) && args.arguments.any?
            visit(node.arguments)
            last_node = @scopes_stack.last&.nodes&.last
            case last_node
            when Method, Attr
              last_node.visibility = parse_visibility(node.name, node)
            else
              raise ParseError.new(
                "Unexpected token `#{node.message}` before `#{last_node&.string&.strip}`",
                node_loc(node),
              )
            end
          else
            current_scope << parse_visibility(node.name, node)
          end
        when "prop", "const"
          parse_tstruct_field(node)
        when "requires_ancestor"
          block = node.block
          return unless block.is_a?(YARP::BlockNode)

          body = block.body
          return unless body.is_a?(YARP::StatementsNode)

          current_scope << RequiresAncestor.new(
            node_string!(body),
            loc: node_loc(node),
            comments: node_comments(node),
          )
        when "sig"
          @last_sigs << parse_sig(node)
        else
          current_scope << Send.new(
            message,
            parse_send_args(node.arguments),
            loc: node_loc(node),
            comments: node_comments(node),
          )
        end
      end

      private

      # Collect all the remaining comments within a node
      sig { params(node: YARP::Node).void }
      def collect_dangling_comments(node)
        first_line = node.location.start_line
        last_line = node.location.end_line

        last_node_last_line = T.unsafe(node).child_nodes.last&.location&.end_line

        last_line.downto(first_line) do |line|
          comment = @comments_by_line[line]
          next unless comment
          break if last_node_last_line && line <= last_node_last_line

          current_scope << parse_comment(comment)
          @comments_by_line.delete(line)
        end
      end

      # Collect all the remaining comments after visiting the tree
      sig { void }
      def collect_orphan_comments
        last_line = T.let(nil, T.nilable(Integer))
        last_node_end = @tree.nodes.last&.loc&.end_line

        @comments_by_line.each do |line, comment|
          # Associate the comment either with the header or the file or as a dangling comment at the end
          recv = if last_node_end && line >= last_node_end
            @tree
          else
            @tree.comments
          end

          # Preserve blank lines in comments
          if last_line && line > last_line + 1
            recv << BlankLine.new(loc: Loc.from_yarp(@file, comment.location))
          end

          recv << parse_comment(comment)
          last_line = line
        end
      end

      sig { returns(Tree) }
      def current_scope
        T.must(@scopes_stack.last) # Should never be nil since we create a Tree as the root
      end

      sig { returns(T::Array[Sig]) }
      def current_sigs
        sigs = @last_sigs.dup
        @last_sigs.clear
        sigs
      end

      sig { returns(T::Array[Comment]) }
      def current_sigs_comments
        comments = @last_sigs_comments.dup
        @last_sigs_comments.clear
        comments
      end

      sig { params(node: YARP::Node).returns(T::Array[Comment]) }
      def node_comments(node)
        comments = []

        start_line = node.location.start_line
        start_line -= 1 unless @comments_by_line.key?(start_line)

        start_line.downto(1) do |line|
          comment = @comments_by_line[line]
          break unless comment

          comments.unshift(parse_comment(comment))
          @comments_by_line.delete(line)
        end

        comments
      end

      sig { params(node: YARP::Comment).returns(Comment) }
      def parse_comment(node)
        Comment.new(node.location.slice.gsub(/^# ?/, "").rstrip, loc: Loc.from_yarp(@file, node.location))
      end

      sig { params(node: T.nilable(YARP::Node)).returns(T::Array[Arg]) }
      def parse_send_args(node)
        args = T.let([], T::Array[Arg])
        return args unless node.is_a?(YARP::ArgumentsNode)

        node.arguments.each do |arg|
          case arg
          when YARP::KeywordHashNode
            arg.elements.each do |assoc|
              next unless assoc.is_a?(YARP::AssocNode)

              args << KwArg.new(
                node_string!(assoc.key).delete_suffix(":"),
                T.must(node_string(assoc.value)),
              )
            end
          else
            args << Arg.new(T.must(node_string(arg)))
          end
        end

        args
      end

      sig { params(node: T.nilable(YARP::Node)).returns(T::Array[Param]) }
      def parse_params(node)
        params = []
        return params unless node.is_a?(YARP::ParametersNode)

        node.requireds.each do |param|
          next unless param.is_a?(YARP::RequiredParameterNode)

          params << ReqParam.new(
            param.name.to_s,
            loc: node_loc(param),
            comments: node_comments(param),
          )
        end

        node.optionals.each do |param|
          next unless param.is_a?(YARP::OptionalParameterNode)

          params << OptParam.new(
            param.name.to_s,
            node_string!(param.value),
            loc: node_loc(param),
            comments: node_comments(param),
          )
        end

        rest = node.rest
        if rest.is_a?(YARP::RestParameterNode)
          params << RestParam.new(
            rest.name&.to_s || "*args",
            loc: node_loc(rest),
            comments: node_comments(rest),
          )
        end

        node.keywords.each do |param|
          next unless param.is_a?(YARP::KeywordParameterNode)

          value = param.value
          params << if value
            KwOptParam.new(
              param.name.to_s.delete_suffix(":"),
              node_string!(value),
              loc: node_loc(param),
              comments: node_comments(param),
            )
          else
            KwParam.new(
              param.name.to_s.delete_suffix(":"),
              loc: node_loc(param),
              comments: node_comments(param),
            )
          end
        end

        rest_kw = node.keyword_rest
        if rest_kw.is_a?(YARP::KeywordRestParameterNode)
          params << KwRestParam.new(
            rest_kw.name&.to_s || "**kwargs",
            loc: node_loc(rest_kw),
            comments: node_comments(rest_kw),
          )
        end

        block = node.block
        if block.is_a?(YARP::BlockParameterNode)
          params << BlockParam.new(
            block.name&.to_s || "&block",
            loc: node_loc(block),
            comments: node_comments(block),
          )
        end

        params
      end

      sig { params(node: YARP::CallNode).returns(Sig) }
      def parse_sig(node)
        @last_sigs_comments = node_comments(node)

        builder = SigBuilder.new(@source, file: @file)
        builder.current.loc = node_loc(node)
        builder.visit_call_node(node)
        builder.current
      end

      sig { params(node: T.any(YARP::ConstantWriteNode, YARP::ConstantPathWriteNode)).returns(T.nilable(Struct)) }
      def parse_struct(node)
        send = node.value
        return unless send.is_a?(YARP::CallNode)
        return unless send.message == "new"

        recv = send.receiver
        return unless recv
        return unless node_string(recv) =~ /(::)?Struct/

        members = []
        keyword_init = T.let(false, T::Boolean)

        args = send.arguments
        if args.is_a?(YARP::ArgumentsNode)
          args.arguments.each do |arg|
            case arg
            when YARP::SymbolNode
              members << arg.value
            when YARP::KeywordHashNode
              arg.elements.each do |assoc|
                next unless assoc.is_a?(YARP::AssocNode)

                key = node_string!(assoc.key)
                val = node_string(assoc.value)

                keyword_init = val == "true" if key == "keyword_init:"
              end
            else
              raise ParseError.new("Unexpected node type `#{arg.class}`", node_loc(arg))
            end
          end
        end

        name = case node
        when YARP::ConstantWriteNode
          node.name.to_s
        when YARP::ConstantPathWriteNode
          node_string!(node.target)
        end

        loc = node_loc(node)
        comments = node_comments(node)
        struct = Struct.new(name, members: members, keyword_init: keyword_init, loc: loc, comments: comments)
        @scopes_stack << struct
        visit(send.block)
        @scopes_stack.pop
        struct
      end

      sig { params(send: YARP::CallNode).void }
      def parse_tstruct_field(send)
        args = send.arguments
        return unless args.is_a?(YARP::ArgumentsNode)

        name_arg, type_arg, *rest = args.arguments
        return unless name_arg
        return unless type_arg

        name = node_string!(name_arg).delete_prefix(":")
        type = node_string!(type_arg)
        loc = node_loc(send)
        comments = node_comments(send)
        default_value = T.let(nil, T.nilable(String))

        rest&.each do |arg|
          next unless arg.is_a?(YARP::KeywordHashNode)

          arg.elements.each do |assoc|
            next unless assoc.is_a?(YARP::AssocNode)

            if node_string(assoc.key) == "default:"
              default_value = node_string(assoc.value)
            end
          end
        end

        current_scope << case send.message
        when "const"
          TStructConst.new(name, type, default: default_value, loc: loc, comments: comments)
        when "prop"
          TStructProp.new(name, type, default: default_value, loc: loc, comments: comments)
        else
          raise ParseError.new("Unexpected message `#{send.message}`", loc)
        end
      end

      sig { params(name: String, node: YARP::Node).returns(Visibility) }
      def parse_visibility(name, node)
        case name
        when "public"
          Public.new(loc: node_loc(node))
        when "protected"
          Protected.new(loc: node_loc(node))
        when "private"
          Private.new(loc: node_loc(node))
        else
          raise ParseError.new("Unexpected visibility `#{name}`", node_loc(node))
        end
      end

      sig { void }
      def separate_header_comments
        current_scope.nodes.dup.each do |child_node|
          break unless child_node.is_a?(Comment) || child_node.is_a?(BlankLine)

          current_scope.comments << child_node
          child_node.detach
        end
      end

      sig { void }
      def set_root_tree_loc
        first_loc = tree.nodes.first&.loc
        last_loc = tree.nodes.last&.loc

        @tree.loc = Loc.new(
          file: @file,
          begin_line: first_loc&.begin_line || 0,
          begin_column: first_loc&.begin_column || 0,
          end_line: last_loc&.end_line || 0,
          end_column: last_loc&.end_column || 0,
        )
      end

      sig { params(node: T.nilable(YARP::Node)).returns(T::Boolean) }
      def type_variable_definition?(node)
        return false unless node.is_a?(YARP::CallNode)
        return false unless node.block

        node.message == "type_member" || node.message == "type_template"
      end
    end

    class SigBuilder < Visitor
      extend T::Sig

      sig { returns(Sig) }
      attr_reader :current

      sig { params(content: String, file: String).void }
      def initialize(content, file:)
        super

        @current = T.let(Sig.new, Sig)
      end

      sig { override.params(node: YARP::CallNode).void }
      def visit_call_node(node)
        case node.message
        when "sig"
          args = node.arguments
          if args.is_a?(YARP::ArgumentsNode)
            args.arguments.each do |arg|
              @current.is_final = node_string(arg) == ":final"
            end
          end
        when "abstract"
          @current.is_abstract = true
        when "checked"
          args = node.arguments
          if args.is_a?(YARP::ArgumentsNode)
            arg = node_string(args.arguments.first)
            @current.checked = arg&.delete_prefix(":")&.to_sym
          end
        when "override"
          @current.is_override = true
        when "overridable"
          @current.is_overridable = true
        when "params"
          visit(node.arguments)
        when "returns"
          args = node.arguments
          if args.is_a?(YARP::ArgumentsNode)
            first = args.arguments.first
            @current.return_type = node_string!(first) if first
          end
        when "type_parameters"
          args = node.arguments
          if args.is_a?(YARP::ArgumentsNode)
            args.arguments.each do |arg|
              @current.type_params << node_string!(arg).delete_prefix(":")
            end
          end
        when "void"
          @current.return_type = nil
        end

        visit(node.receiver)
        visit(node.block)
      end

      sig { override.params(node: YARP::AssocNode).void }
      def visit_assoc_node(node)
        @current.params << SigParam.new(
          node_string!(node.key).delete_suffix(":"),
          node_string!(T.must(node.value)),
        )
      end
    end
  end
end
