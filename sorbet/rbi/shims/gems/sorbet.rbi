# typed: strict
# frozen_string_literal: true

module T
  module Types
    class AttachedClassType < Base
      module Private; end
    end
  end

  module Private
    class Abstract
      class Data
        class << self
          def get(mod, key); end
          def set_default(mod, key, value); end
        end
      end
    end

    class Final
      class << self
        def final_module?(mod); end
      end
    end

    class Sealed
      class << self
        def sealed_module?(mod); end
      end
    end

    module Types
      class NotTyped < T::Types::Base; end

      class StringHolder < T::Types::Base
        def initialize(str); end
      end
    end

    module Methods
      ARG_NOT_PROVIDED = T.let(T.unsafe(nil), Object)

      class Declaration
        def on_failure; end
        def on_failure=(on_failure); end

        def override_allow_incompatible; end
        def override_allow_incompatible=(override_allow_incompatible); end

        def type_parameters; end
        def type_parameters=(type_parameters); end

        def raw; end
        def raw=(raw); end

        def mod; end
        def mod=(mod); end

        def params; end
        def params=(params); end

        def returns; end
        def returns=(returns); end

        def bind; end
        def bind=(bind); end

        def mode; end
        def mode=(mode); end

        def checked; end
        def checked=(checked); end

        def finalized; end
        def finalized=(finalized); end
      end
    end
  end

  class Enum
    def values; end
  end
end
