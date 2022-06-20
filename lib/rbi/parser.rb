# typed: strict
# frozen_string_literal: true

require "syntax_tree"

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

    sig { params(string: String).returns(Tree) }
    def self.parse_string(string)
      Parser.new.parse_string(string)
    end

    sig { params(path: String).returns(Tree) }
    def self.parse_file(path)
      Parser.new.parse_file(path)
    end

    sig { params(paths: T::Array[String]).returns(T::Array[Tree]) }
    def self.parse_files(paths)
      parser = Parser.new
      paths.map { |path| parser.parse_file(path) }
    end

    sig { params(string: String).returns(Tree) }
    def parse_string(string)
      parse(string, file: "-")
    end

    sig { params(strings: T::Array[String]).returns(T::Array[Tree]) }
    def self.parse_strings(strings)
      parser = Parser.new
      strings.map { |string| parser.parse_string(string) }
    end

    sig { params(path: String).returns(Tree) }
    def parse_file(path)
      parse(::File.read(path), file: path)
    end

    private

    sig { params(content: String, file: String).returns(Tree) }
    def parse(content, file:)
      builder = TreeBuilder.new(file: file, source: content)
      builder.visit(SyntaxTree::Parser.new(content).parse)
      builder.tree
    rescue SyntaxTree::Parser::ParseError => e
      loc = Loc.new(file: file, begin_line: e.lineno, begin_column: e.column, end_line: e.lineno, end_column: e.column)
      raise ParseError.new(e.message, loc)
    rescue ParseError => e
      raise e
    rescue => e
      last_node = builder&.last_node
      last_location = if last_node
        Loc.from_syntax_tree_loc(file, last_node.location)
      else
        Loc.new(file: file)
      end

      exception = UnexpectedParserError.new(e, last_location)
      exception.print_debug
      raise exception
    end

    class DefNode < T::Struct
      const :node, T.any(SyntaxTree::Def, SyntaxTree::DefEndless, SyntaxTree::Defs)
      const :is_singleton, T::Boolean
    end

    class SendNode < T::Struct
      const :node, T.any(
        SyntaxTree::Call,
        SyntaxTree::Command,
        SyntaxTree::FCall,
        SyntaxTree::VCall,
        SyntaxTree::MethodAddBlock
      )
      const :name, String
      const :args, T::Array[SyntaxTree::Node], default: []
      const :block_statements, T.nilable(SyntaxTree::Statements)
    end

    class Visitor < SyntaxTree::Visitor
      extend T::Sig

      sig { params(node: DefNode).void }
      def visit_method_def(node)
      end

      sig { override.params(node: SyntaxTree::Def).void }
      def visit_def(node)
        visit_method_def(DefNode.new(node: node, is_singleton: false))
      end

      sig { override.params(node: SyntaxTree::DefEndless).void }
      def visit_def_endless(node)
        visit_method_def(DefNode.new(node: node, is_singleton: false))
      end

      sig { override.params(node: SyntaxTree::Defs).void }
      def visit_defs(node)
        visit_method_def(DefNode.new(node: node, is_singleton: true))
      end

      sig { params(node: SendNode).void }
      def visit_send(node)
      end

      sig { override.params(node: SyntaxTree::Command).void }
      def visit_command(node)
        args_node = node.arguments
        args_node = args_node.arguments if args_node.is_a?(SyntaxTree::ArgParen)
        visit_send(SendNode.new(node: node, name: node.message.value, args: args_node.parts))
      end

      sig { override.params(node: SyntaxTree::FCall).void }
      def visit_fcall(node)
        args_node = node.arguments
        args_node = args_node.arguments if args_node.is_a?(SyntaxTree::ArgParen)
        visit_send(SendNode.new(node: node, name: node.value.value, args: args_node.parts))
      end

      sig { override.params(node: SyntaxTree::VCall).void }
      def visit_vcall(node)
        visit_send(SendNode.new(node: node, name: node.value.value))
      end

      sig { override.params(node: SyntaxTree::MethodAddBlock).void }
      def visit_method_add_block(node)
        args_node = node.call.arguments
        args_node = args_node.arguments if args_node.is_a?(SyntaxTree::ArgParen)

        block_node = node.block
        statements = case block_node
        when SyntaxTree::BraceBlock
          block_node.statements
        when SyntaxTree::DoBlock
          block_node.bodystmt.statements
        end

        visit_send(
          SendNode.new(node: node, name: node.call.value.value, args: args_node.parts, block_statements: statements)
        )
      end
    end

    class TreeBuilder < Visitor
      extend T::Sig

      sig { returns(Tree) }
      attr_reader :tree

      sig { returns(String) }
      attr_reader :source

      sig { returns(T.nilable(SyntaxTree::Node)) }
      attr_reader :last_node

      sig { params(file: String, source: String).void }
      def initialize(file:, source:)
        super()
        @file = file
        @source = source
        @tree = T.let(Tree.new, Tree)
        @scopes_stack = T.let([@tree], T::Array[Tree])
        @last_node = T.let(nil, T.nilable(SyntaxTree::Node))
        @last_comments = T.let([], T::Array[Comment])
        @last_sigs = T.let([], T::Array[Sig])
      end

      sig { override.params(node: T.nilable(SyntaxTree::Node)).void }
      def visit(node)
        return unless node

        @last_node = node
        super
        @last_node = nil
      end

      sig { override.params(node: SyntaxTree::Program).void }
      def visit_program(node)
        current_scope.loc = node_loc(node)
        super

        collect_dangling_comments
        separate_header_comments
      end

      sig { override.params(node: SyntaxTree::Comment).void }
      def visit_comment(node)
        @last_comments << parse_comment(node)
      end

      sig { override.params(node: SyntaxTree::ClassDeclaration).void }
      def visit_class(node)
        scope = Class.new(
          T.must(node_string(node.constant)),
          superclass_name: node_string(node.superclass),
          loc: node_loc(node),
          comments: node_comments(node)
        )
        current_scope << scope
        @scopes_stack << scope
        super
        collect_dangling_comments
        @scopes_stack.pop
      end

      sig { override.params(node: SyntaxTree::ModuleDeclaration).void }
      def visit_module(node)
        scope = Module.new(
          T.must(node_string(node.constant)),
          loc: node_loc(node),
          comments: node_comments(node)
        )
        current_scope << scope
        @scopes_stack << scope
        super
        collect_dangling_comments
        @scopes_stack.pop
      end

      sig { override.params(node: SyntaxTree::SClass).void }
      def visit_sclass(node)
        scope = SingletonClass.new(
          loc: node_loc(node),
          comments: node_comments(node)
        )
        current_scope << scope
        @scopes_stack << scope
        super
        collect_dangling_comments
        @scopes_stack.pop
      end

      sig { override.params(node: SyntaxTree::Assign).void }
      def visit_assign(node)
        target = node.target

        return unless target.is_a?(SyntaxTree::ConstPathField) || target.is_a?(SyntaxTree::TopConstField) ||
          (target.is_a?(SyntaxTree::VarField) && target.value.is_a?(SyntaxTree::Const))

        current_scope << if struct_new?(node.value)
          parse_struct(node)
        else
          Const.new(
            T.must(node_string(target)),
            T.must(node_string(node.value)),
            loc: node_loc(node),
            comments: node_comments(node)
          )
        end
      end

      sig { params(node: SyntaxTree::Node).returns(T::Boolean) }
      def struct_new?(node)
        call = case node
        when SyntaxTree::Call
          node
        when SyntaxTree::MethodAddBlock
          block_call = node.call
          case block_call
          when SyntaxTree::Call
            block_call
          else
            return false
          end
        else
          return false
        end

        return false unless node_string(call.receiver) =~ /(::)?Struct/

        method_name = call.message&.value
        return false unless method_name == "new"

        true
      end

      sig { override.params(node: DefNode).void }
      def visit_method_def(node)
        current_scope << Method.new(
          node.node.name.value,
          params: parse_params(node.node),
          sigs: current_sigs,
          loc: node_loc(node.node),
          comments: node_comments(node.node),
          is_singleton: node.is_singleton
        )
      end

      sig { override.params(node: SendNode).void }
      def visit_send(node)
        method_name = node.name
        case method_name
        when "attr_reader"
          current_scope << AttrReader.new(
            *T.unsafe(node.args.map { |arg| T.must(T.must(node_string(arg))[1..-1]).to_sym }),
            sigs: current_sigs,
            loc: node_loc(node.node),
            comments: node_comments(node.node)
          )
        when "attr_writer"
          current_scope << AttrWriter.new(
            *T.unsafe(node.args.map { |arg| T.must(T.must(node_string(arg))[1..-1]).to_sym }),
            sigs: current_sigs,
            loc: node_loc(node.node),
            comments: node_comments(node.node)
          )
        when "attr_accessor"
          current_scope << AttrAccessor.new(
            *T.unsafe(node.args.map { |arg| T.must(T.must(node_string(arg))[1..-1]).to_sym }),
            sigs: current_sigs,
            loc: node_loc(node.node),
            comments: node_comments(node.node)
          )
        when "include"
          current_scope << Include.new(
            *T.unsafe(node.args.map { |arg| T.must(node_string(arg)) }),
            loc: node_loc(node.node),
            comments: node_comments(node.node)
          )
        when "extend"
          current_scope << Extend.new(
            *T.unsafe(node.args.map { |arg| T.must(node_string(arg)) }),
            loc: node_loc(node.node),
            comments: node_comments(node.node)
          )
        when "mixes_in_class_methods"
          current_scope << MixesInClassMethods.new(
            *T.unsafe(node.args.map { |arg| T.must(node_string(arg)) }),
            loc: node_loc(node.node),
            comments: node_comments(node.node)
          )
        when "private", "protected", "public"
          case node.node
          when SyntaxTree::VCall
            current_scope << parse_visibility(node.name, node.node)
          when SyntaxTree::Command
            visit_all(node.args)
            last_node = @scopes_stack.last&.nodes&.last
            case last_node
            when Method, Attr
              last_node.visibility = parse_visibility(node.name, node.node)
            else
              raise ParseError.new("Unexpected token `#{node.name}`", node_loc(node.node))
            end
          end
        when "abstract!", "sealed!", "interface!"
          current_scope << Helper.new(
            method_name.delete_suffix("!"),
            loc: node_loc(node.node),
            comments: node_comments(node.node)
          )
        when "prop", "const"
          current_scope << parse_tstruct_field(node.node, method_name, node.args)
        when "sig"
          @last_sigs << SigBuilder.build(self, node.node)
        when "enums"
          current_scope << TEnumBlock.new(
            node.block_statements&.body&.map { |stmt| T.must(node_string(stmt.target)) },
            loc: node_loc(node.node),
            comments: node_comments(node.node)
          )
        when "requires_ancestor"
          current_scope << RequiresAncestor.new(
            T.must(node_string(node.block_statements&.body&.first)),
            loc: node_loc(node.node),
            comments: node_comments(node.node)
          )
        else
          current_scope << Send.new(
            method_name,
            parse_send_args(node.args),
            loc: node_loc(node.node),
            comments: node_comments(node.node)
          )
        end
      end

      sig { params(name: String, node: SyntaxTree::Node).returns(Visibility) }
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

      sig { params(node: SyntaxTree::Node).returns(Loc) }
      def node_loc(node)
        Loc.from_syntax_tree_loc(@file, node.location)
      end

      sig { params(node: SyntaxTree::Node).returns(T::Array[Comment]) }
      def node_comments(node)
        node_comments = []
        unless @last_comments.empty?
          current_line = node.location.start_line
          @last_comments.reverse.each do |comment|
            comment_loc = T.must(comment.loc)
            if comment_loc.end_line == current_line - 1
              node_comments << @last_comments.pop
              current_line = comment_loc.end_line
            end
          end
        end

        collect_dangling_comments

        node_comments.reverse!
        T.unsafe(node).comments.each do |comment_node|
          node_comments << parse_comment(comment_node)
        end
        node_comments
      end

      sig { params(node: T.nilable(SyntaxTree::Node)).returns(T.nilable(String)) }
      def node_string(node)
        return nil unless node

        @source[node.location.start_char...node.location.end_char]
      end

      private

      sig { void }
      def separate_header_comments
        current_scope.nodes.dup.each do |child_node|
          break unless child_node.is_a?(Comment) || child_node.is_a?(BlankLine)

          current_scope.comments << child_node
          child_node.detach
        end
      end

      sig { void }
      def collect_dangling_comments
        last_line = T.let(nil, T.nilable(Integer))

        @last_comments.each do |comment|
          comment_line = T.must(comment.loc&.begin_line)

          if last_line && comment_line > last_line + 1
            # Preserve empty lines in file headers
            current_scope << BlankLine.new(loc: comment.loc)
          end

          current_scope << comment

          last_line = T.must(comment.loc&.end_line)
        end
        @last_comments.clear
      end

      sig { params(node: SyntaxTree::Comment).returns(Comment) }
      def parse_comment(node)
        Comment.new(node.value.gsub(/^# ?/, ""), loc: node_loc(node))
      end

      sig { params(node: T.any(SyntaxTree::Def, SyntaxTree::DefEndless, SyntaxTree::Defs)).returns(T::Array[Param]) }
      def parse_params(node)
        v = ParamsBuilder.new(self)
        v.visit(node)
        v.params
      end

      sig { params(nodes: T::Array[SyntaxTree::Node]).returns(T::Array[Arg]) }
      def parse_send_args(nodes)
        args = T.let([], T::Array[Arg])
        nodes.each do |child|
          case child
          when SyntaxTree::BareAssocHash
            child.assocs.each do |assoc|
              keyword = assoc.key.value[0..-2]
              value = T.must(node_string(assoc.value))
              args << KwArg.new(keyword, value)
            end
          else
            args << Arg.new(T.must(node_string(child)))
          end
        end
        args
      end

      sig { params(node: SyntaxTree::Assign).returns(RBI::Struct) }
      def parse_struct(node)
        name = T.must(node_string(node.target))
        loc = node_loc(node)
        comments = node_comments(node)

        block = T.let(nil, T.nilable(SyntaxTree::Node))
        call = T.let(case node.value
               when SyntaxTree::Call
                 node.value
               when SyntaxTree::MethodAddBlock
                 block = node.value.block
                 node.value.call
               else
                 raise ParseError.new("Unexpected node type `#{node.value.class}`", loc)
               end, SyntaxTree::Call)

        members = []
        keyword_init = T.let(false, T::Boolean)

        call.arguments&.arguments&.parts&.each do |arg|
          case arg
          when SyntaxTree::SymbolLiteral
            members << arg.value.value
          when SyntaxTree::BareAssocHash
            arg.assocs.each do |assoc|
              case assoc.key.value[0..-2]
              when "keyword_init"
                keyword_init = T.must(node_string(assoc.value)) == "true"
              end
            end
          else
            raise ParseError.new("Unexpected node type `#{arg.class}`", node_loc(arg))
          end
        end

        struct = Struct.new(name, members: members, keyword_init: keyword_init, loc: loc, comments: comments)
        @scopes_stack << struct
        visit(block)
        @scopes_stack.pop
        struct
      end

      sig do
        params(
          node: SyntaxTree::Node,
          method_name: String,
          args: T::Array[SyntaxTree::Node]
        ).returns(TStructField)
      end
      def parse_tstruct_field(node, method_name, args)
        name = T.must(T.must(node_string(args.first))[1..-1])
        type = T.must(node_string(args[1]))
        default_value = T.let(nil, T.nilable(String))
        loc = node_loc(node)
        comments = node_comments(node)

        if args.size > 2
          options_hash = args[2]
          raise ParseError.new("Unexpected struct field args", loc) unless options_hash.is_a?(SyntaxTree::BareAssocHash)

          options_hash.assocs.each do |assoc|
            case assoc.key.value[0..-2]
            when "default"
              default_value = T.must(node_string(assoc.value))
            else
              raise ParseError.new("Unexpected struct field option #{assoc.key.value}", loc)
            end
          end
        end

        case method_name
        when "const"
          TStructConst.new(name, type, default: default_value, loc: loc, comments: comments)
        when "prop"
          TStructProp.new(name, type, default: default_value, loc: loc, comments: comments)
        else
          raise ParseError.new("Unexpected #{method_name} command for TStructField", loc)
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
    end

    class SigBuilder < SyntaxTree::Visitor
      extend T::Sig

      sig { params(builder: TreeBuilder, node: SyntaxTree::Node).returns(Sig) }
      def self.build(builder, node)
        v = SigBuilder.new(builder)
        v.current.loc = builder.node_loc(node)
        v.visit(node)
        v.current
      end

      sig { returns(Sig) }
      attr_accessor :current

      sig { params(builder: TreeBuilder).void }
      def initialize(builder)
        super()
        @builder = builder
        @current = T.let(Sig.new, Sig)
      end

      sig { params(node: T.nilable(SyntaxTree::Node)).void }
      def visit(node)
        return unless node

        case node
        when SyntaxTree::Call
          arguments = node_arguments(node)
          add_sig_builder(node.message.value, arguments)
          visit(node.receiver)
        when SyntaxTree::FCall
          arguments = node_arguments(node)
          add_sig_builder(node.value.value, arguments)
        when SyntaxTree::Ident
          add_sig_builder(node.value, nil)
        else
          super
        end
      end

      sig { params(name: String, arguments: T.nilable(SyntaxTree::Args)).void }
      def add_sig_builder(name, arguments)
        case name
        when "sig"
          arguments&.parts&.each do |argument|
            @current.is_final = @builder.node_string(argument) == ":final"
          end
        when "abstract"
          @current.is_abstract = true
        when "override"
          @current.is_override = true
        when "overridable"
          @current.is_overridable = true
        when "checked"
          arg = @builder.node_string(arguments)
          @current.checked = arg ? arg[1..-1]&.to_sym : nil
        when "params"
          visit(arguments)
        when "returns"
          @current.return_type = T.must(@builder.node_string(arguments)) if arguments
        when "type_parameters"
          arguments&.parts&.each do |argument|
            @current.type_params << T.must(T.must(@builder.node_string(argument))[1..-1])
          end
        when "void"
          @current.return_type = nil
        end
      end

      sig { params(node: SyntaxTree::BareAssocHash).void }
      def visit_bare_assoc_hash(node)
        node.assocs.each do |assoc|
          @current.params << SigParam.new(
            T.must(T.must(@builder.node_string(assoc.key))[0..-2]),
            T.must(@builder.node_string(assoc.value))
          )
        end
      end

      sig { params(node: T.any(SyntaxTree::Call, SyntaxTree::FCall)).returns(T.nilable(SyntaxTree::Args)) }
      def node_arguments(node)
        arguments = node.arguments
        arguments.is_a?(SyntaxTree::ArgParen) ? arguments.arguments : arguments
      end
    end

    class ParamsBuilder < SyntaxTree::Visitor
      extend T::Sig

      sig { params(builder: TreeBuilder, node: T.nilable(SyntaxTree::Node)).returns(T::Array[Param]) }
      def self.visit(builder, node)
        v = ParamsBuilder.new(builder)
        v.visit(node)
        v.params
      end

      sig { returns(T::Array[Param]) }
      attr_accessor :params

      sig { params(builder: TreeBuilder).void }
      def initialize(builder)
        super()
        @builder = builder
        @params = T.let([], T::Array[Param])
      end

      sig { override.params(node: SyntaxTree::Params).void }
      def visit_params(node)
        node.requireds.each do |ident|
          @params << ReqParam.new(
            ident.value,
            loc: @builder.node_loc(ident),
            comments: @builder.node_comments(ident)
          )
        end
        node.optionals.each do |(ident, value)|
          @params << OptParam.new(
            ident.value,
            T.must(@builder.node_string(value)),
            loc: @builder.node_loc(ident),
            comments: @builder.node_comments(ident)
          )
        end
        if node.rest
          @params << RestParam.new(
            node.rest.name&.value || "",
            loc: @builder.node_loc(node.rest),
            comments: @builder.node_comments(node.rest)
          )
        end
        node.keywords.each do |(ident, value)|
          @params << if value
            KwOptParam.new(
              ident.value[0..-2],
              T.must(@builder.node_string(value)),
              loc: @builder.node_loc(ident),
              comments: @builder.node_comments(ident)
            )
          else
            KwParam.new(
              ident.value[0..-2],
              loc: @builder.node_loc(ident),
              comments: @builder.node_comments(ident)
            )
          end
        end
        if node.keyword_rest
          @params << KwRestParam.new(
            node.keyword_rest.name.value,
            loc: @builder.node_loc(node.keyword_rest),
            comments: @builder.node_comments(node.keyword_rest)
          )
        end
        if node.block
          @params << BlockParam.new(
            node.block.name.value,
            loc: @builder.node_loc(node.block),
            comments: @builder.node_comments(node.block)
          )
        end
      end
    end
  end

  class Loc
    sig { params(file: String, syntax_tree_loc: SyntaxTree::Location).returns(Loc) }
    def self.from_syntax_tree_loc(file, syntax_tree_loc)
      Loc.new(
        file: file,
        begin_line: syntax_tree_loc.start_line,
        begin_column: syntax_tree_loc.start_column,
        end_line: syntax_tree_loc.end_line,
        end_column: syntax_tree_loc.end_column
      )
    end
  end
end
