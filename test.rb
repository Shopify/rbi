module A
  module B
    class C
      class D < C; end
    end
  end
end

module Foo
  class << self

  end
end
