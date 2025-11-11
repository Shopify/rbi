# typed: false
# frozen_string_literal: true

# Prototype for runtime type checking
# Uses TracePoint to trace method calls and returns
# Transforms the method calls into a method definition:
# Example:
# For method_call X.foo(Integer)
# the method definition will be:
# #: (recv: X, arg0: Integer) -> void
# def random_method_name(recv, arg0)
#   recv.foo(arg0)
# end
#
# Writes the method calls to a file
# We can then run Sorbet on the file, effectively converting runtime type checking to static type checking
# Triggered like this for tests in test_helper.rb:
# tracer = RBI::Tracer.new
# tracer.start
# Minitest.after_run do
#   tracer.stop
# end

require "securerandom"

module RBI
  MethodCalls = []

  class MethodCall
    attr_reader :recv, :method_name, :arguments, :return_type

    def initialize(recv, method_name, arguments, return_type)
      @recv = recv
      @method_name = method_name
      @arguments = arguments
      @return_type = return_type
    end

    def to_s
      "#{recv.class.name}.#{method_name}(#{arguments.inspect}) -> #{return_type.inspect}"
    end

    def to_method_def
      # arguments.each do |arg|
      #   puts arg.inspect
      # end
      arguments = self.arguments.compact
      <<~RB
        #: (recv: #{recv.class.name}#{", " unless arguments.empty?} #{arguments.map.with_index { |arg, index| "arg_#{index}: #{arg}" }.join(", ")}) -> #{return_type&.name || "void"}
        def method_#{SecureRandom.alphanumeric(10)}(recv:, #{arguments.map.with_index { |_arg, index| "arg_#{index}:" }.join(", ")})
          recv.#{method_name}(#{arguments.map.with_index { |_arg, index| "arg_#{index}" }.join(", ")})
        end
      RB
    end
  end

  class Tracer
    def initialize
      @trace = nil
    end

    def start
      puts "Starting tracer"
      @trace = TracePoint.new(:a_call, :a_return) do |tp|
        handle_event(tp)
      end
      @trace.enable
    end

    def stop
      puts "Stopping tracer"
      @trace.disable
      content = "# typed: true\n\n" + MethodCalls.map(&:to_method_def).join("\n")
      ::File.write("method_calls.rb", content)
    end

    private

    def handle_event(tp)
      # puts "Handling event: #{tp.class.inspect}"
      return unless tp.path.include?("rbi/index.rb")

      case tp.event
      when :a_call, :c_call, :call, :b_call
        handle_a_call(tp)
      when :a_return, :c_return, :return, :b_return
        handle_a_return(tp)
      else
        raise "Unhandled event: #{tp.event.inspect}"
      end
    end

    def handle_a_call(tp)
      # puts "CALL: #{tp.method_id}, #{tp.parameters.inspect}"
      # puts "#{tp.self.class.name}.#{tp.method_id}"

      # param_names = tp.parameters.select { |type, _name| type == :req }.map { |_type, name| name }
      # # get argument values from the binding
      # args = param_names.map { |name| tp.binding&.local_variable_get(name)&.class }
      # puts "Calling #{tp.defined_class}##{tp.method_id} with args: #{args.inspect}"

      # Available TracePoint data:
      # tp.method_id       - method name (Symbol)
      # tp.defined_class   - class/module where method is defined
      # tp.self            - receiver object
      # tp.binding         - binding at the point
      # tp.path            - file path
      # tp.lineno          - line number
      # tp.event           - event type (:a_call)
      # tp.parameters      - method parameters
    end

    def handle_a_return(tp)
      param_names = tp.parameters.select { |type, _name| type == :req }.map { |_type, name| name }
      # get argument values from the binding
      args = param_names.map { |name| tp.binding&.local_variable_get(name)&.class }
      method_call = MethodCall.new(tp.self, tp.method_id, args, tp.return_value&.class)
      MethodCalls << method_call
      # puts "Calling #{tp.defined_class}##{tp.method_id} with args: #{args.inspect}"

      # return_type = tp.return_value&.class
      # puts "Returning from #{tp.defined_class}##{tp.method_id} with return type: #{return_type.inspect}"
      # Available TracePoint data (same as a_call, plus):
      # tp.return_value    - the return value of the method
    end
  end
end
