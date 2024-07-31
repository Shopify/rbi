# typed: strict
# frozen_string_literal: true

module RBI
  class UnexpectedMultipleSigsError < Error
    sig { returns(Node) }
    attr_reader :node

    sig { params(node: Node).void }
    def initialize(node)
      super(<<~MSG)
        This declaration cannot have more than one sig.

        #{node.string.chomp}
      MSG

      @node = node
    end
  end

  module Rewriters
    class AttrToMethods < Visitor
      extend T::Sig

      sig { override.params(node: T.nilable(Node)).void }
      def visit(node)
        case node
        when Tree
          visit_all(node.nodes.dup)

        when Attr
          replace(node, with: node.convert_to_methods)
        end
      end

      private

      sig { params(node: Node, with: T::Array[Node]).void }
      def replace(node, with:)
        tree = node.parent_tree
        raise ReplaceNodeError, "Can't replace #{self} without a parent tree" unless tree

        node.detach
        with.each { |node| tree << node }
      end
    end
  end

  class Tree
    extend T::Sig

    sig { void }
    def replace_attributes_with_methods!
      visitor = Rewriters::AttrToMethods.new
      visitor.visit(self)
    end
  end

  class Attr
    sig { abstract.returns(T::Array[Method]) }
    def convert_to_methods; end

    private

    sig(:final) { returns([T.nilable(Sig), T.nilable(T.any(Type, String))]) }
    def parse_sig
      raise UnexpectedMultipleSigsError, self if 1 < sigs.count

      sig = sigs.first
      return [nil, nil] unless sig

      attribute_type = case self
      when AttrReader, AttrAccessor then sig.return_type
      when AttrWriter then sig.params.first&.type
      end

      [sig, attribute_type]
    end

    sig do
      params(
        name: String,
        sig: T.nilable(Sig),
        visibility: Visibility,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
      ).returns(Method)
    end
    def create_getter_method(name, sig, visibility, loc, comments)
      Method.new(
        name,
        params: [],
        visibility: visibility,
        sigs: sig ? [sig] : [],
        loc: loc,
        comments: comments,
      )
    end

    sig do
      params(
        name: String,
        sig: T.nilable(Sig),
        attribute_type: T.nilable(T.any(Type, String)),
        visibility: Visibility,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
      ).returns(Method)
    end
    def create_setter_method(name, sig, attribute_type, visibility, loc, comments) # rubocop:disable Metrics/ParameterLists
      sig = if sig # Modify the original sig to correct the name, and remove the return type
        params = attribute_type ? [SigParam.new(name, attribute_type)] : []

        Sig.new(
          params: params,
          return_type: "void",
          is_abstract: sig.is_abstract,
          is_override: sig.is_override,
          is_overridable: sig.is_overridable,
          is_final: sig.is_final,
          type_params: sig.type_params,
          checked: sig.checked,
          loc: sig.loc,
        )
      end

      Method.new(
        "#{name}=",
        params: [ReqParam.new(name)],
        visibility: visibility,
        sigs: sig ? [sig] : [],
        loc: loc,
        comments: comments,
      )
    end
  end

  class AttrAccessor
    sig { override.returns(T::Array[Method]) }
    def convert_to_methods
      sig, attribute_type = parse_sig

      names.flat_map do |name|
        [
          create_getter_method(name.to_s, sig, visibility, loc, comments),
          create_setter_method(name.to_s, sig, attribute_type, visibility, loc, comments),
        ]
      end
    end
  end

  class AttrReader
    sig { override.returns(T::Array[Method]) }
    def convert_to_methods
      sig, _ = parse_sig

      names.map { |name| create_getter_method(name.to_s, sig, visibility, loc, comments) }
    end
  end

  class AttrWriter
    sig { override.returns(T::Array[Method]) }
    def convert_to_methods
      sig, attribute_type = parse_sig

      names.map { |name| create_setter_method(name.to_s, sig, attribute_type, visibility, loc, comments) }
    end
  end
end
