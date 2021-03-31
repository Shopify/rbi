# typed: true
# frozen_string_literal: true

module RBI
  class CLI < ::Thor
    extend T::Sig

    desc 'foo', ''
    def foo(*paths)
      puts "Hello!"
    end

    no_commands do
    end
  end
end