class Foo
  def foo; end

  # @version <= 1.0.0
  def bar; end

  # @version > 1.0.0
  def bar(x); end
end

# @version > 0.1.0
# @version < 0.9.0
class Bar
  def baz2; end
end

# @version > 1.0.0
class Bar
  def baz; end
end
