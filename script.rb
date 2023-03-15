# typed: true

require 'rbi'
# require 'gem'

class VersionVisitor < RBI::Visitor
  extend T::Sig

  sig { params(version: Gem::Version).void }
  def initialize(version)
    super()
    @version = version
  end

  sig { override.params(node: T.nilable(RBI::Node)).void }
  def visit(node)
    return unless node

    if node.is_a?(RBI::NodeWithComments)
      requirements = node.annotations.select do |annotation|
        annotation.start_with?("version")
      end.map do |annotation|
        versions = annotation.delete_prefix("version ").split(/, */)
        Gem::Requirement.new(versions)
      end

      if !requirements.empty? && requirements.none? { |req| req.satisfied_by?(@version) }
        node.detach
        return
      end
    end

    visit_all(node.nodes.dup) if node.is_a?(RBI::Tree)
  end
end

ast = RBI::Parser.parse_file('foo.rbi')
v = VersionVisitor.new(Gem::Version.new(ARGV.first))
v.visit(ast)
puts ast.string
