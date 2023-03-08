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
    puts node

    if node.is_a?(RBI::NodeWithComments)
      annotations = node.annotations.select do |annotation|
        annotation.start_with?("version")
      end.map do |annotation|
        annotation.delete_prefix("version ")
      end

      to_detach = T.let(false, T::Boolean)

      annotations.each do |annotation|
        operator, version_str = annotation.split(" ")
        version = Gem::Version.new(version_str)

        case operator
        when ">"
          puts "#{@version} > #{version}"
          to_detach = true unless @version > version
        when ">="
          puts "#{@version}>= #{version}"
          to_detach = true unless @version >= version
        when "<="
          puts "#{@version}<=#{version}"
          to_detach = true unless @version <= version
        when "<"
          puts "#{@version}< #{version}"
          to_detach = true unless @version < version
        end
      end

      if to_detach
        node.detach
      else
        visit_all(node.nodes) if node.is_a?(RBI::Tree)
        return
      end
    end

    visit_all(node.nodes) if node.is_a?(RBI::Tree)
  end
end

ast = RBI::Parser.parse_file('foo.rbi')
v = VersionVisitor.new(Gem::Version.new("0.9.0"))
v.visit(ast)
puts ast.string
