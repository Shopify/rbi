class Foo
  def foo; end

  # @version < 0.1.0
  # @version > 0.7.0
  def buzz; end

  # @version > 0.1.0, < 0.7.0
  def biz; end

  # @version <= 1.0.0
  def bar; end

  # @version > 1.0.0
  def bar(x); end

  # @version = 0.8.0
  def beez; end
end

# @version > 0.1.0, < 0.9.0
class Bar
  def baz2; end
end

# @version >= 2.0.0
class Class1; end

# @version > 1.0.0
class Bar
  def baz; end
end

class Class2; end
