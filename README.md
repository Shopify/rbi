# RBI generation framework

`RBI` provides a Ruby API to build, parse, print, format, rewrite, and merge Ruby Interface files consumed by Sorbet.

## Installation

`rbi` requires Ruby 3.3 or newer.

Add this line to your application's Gemfile:

```ruby
gem "rbi"
```

And then execute:

```sh
bundle install
```

Or install it yourself as:

```sh
gem install rbi
```

## Usage

### Generating RBI

```rb
require "rbi"

rbi = RBI::File.new(strictness: "true") do |file|
  file << RBI::Module.new("Foo") do |mod|
    mod << RBI::Method.new("foo")
  end
end

puts rbi.string
```

will produce:

```rb
# typed: true

module Foo
  def foo; end
end
```

### Parsing RBI

```rb
require "rbi"

tree = RBI::Parser.parse_string(<<~RBI)
  class Foo
    def bar; end
  end
RBI

puts tree.nodes.first.fully_qualified_name # => ::Foo
```

### Formatting and rewriting RBI

```rb
require "rbi"

tree = RBI::Parser.parse_string(<<~RBI)
  class Foo
    def bar; end
  end
RBI

formatter = RBI::Formatter.new(add_sig_templates: true, group_nodes: true, sort_nodes: true)
formatter.format_tree(tree)

puts tree.string
```

will produce:

```rb
class Foo
  # TODO: fill in signature with appropriate type information
  sig { returns(::T.untyped) }
  def bar; end
end
```

### Merging RBI trees

```rb
require "rbi"

left = RBI::Parser.parse_string(<<~RBI)
  class Foo
    def a; end
  end
RBI

right = RBI::Parser.parse_string(<<~RBI)
  class Foo
    def b; end
  end
RBI

puts left.merge(right).string
```

will produce:

```rb
class Foo
  def a; end
  def b; end
end
```

### Working with Sorbet types

```rb
require "rbi"

type = RBI::Type.parse_string("T.nilable(String)")

puts type # => ::T.nilable(String)
puts type.rbs_string # => String?
```

### Translating RBS comments to Sorbet signatures

```rb
require "rbi"

tree = RBI::Parser.parse_string(<<~RBI)
  #: (String) -> Integer
  def foo(name); end
RBI

tree.translate_rbs_sigs!

puts tree.string
```

will produce:

```rb
sig { params(name: String).returns(Integer) }
def foo(name); end
```

### Printing RBS

```rb
require "rbi"

file = RBI::File.new do |f|
  f << RBI::Class.new("User") do |klass|
    klass << RBI::Method.new("name", sigs: [RBI::Sig.new(return_type: "String")])
  end
end

puts file.rbs_string
```

will produce:

```rbs
class User
  def name: -> String
end
```

## Features

* RBI generation API
* RBI parsing with Prism
* RBI printing and formatting
* RBI tree merging
* RBI normalization rewrites
* Sorbet type parsing and modeling
* RBS comments to Sorbet signature translation
* RBS output via `RBI::RBSPrinter`

## Development

After checking out the repo, run `bin/setup` to install dependencies.

Useful commands:

* `bin/test` runs the test suite
* `bin/typecheck` runs Sorbet
* `bin/style` runs RuboCop
* `bin/console` starts an interactive prompt

## Releasing

### Bump the gem version

* [ ] Locally, update the version number in [`version.rb`](https://github.com/Shopify/rbi/blob/main/lib/rbi/version.rb)
* [ ] Run `bundle install` to update the version number in `Gemfile.lock`
* [ ] Commit this change with the message `Bump version to vx.y.z`
* [ ] Push this change directly to main or open a PR

### Create a new tag

* [ ] Locally, create a new tag with the new version number: `git tag vx.y.z`
* [ ] Push this tag up to the remote `git push origin vx.y.z`

### Release workflow will run automatically

We have a [release workflow](https://github.com/Shopify/rbi/actions/workflows/release.yml) that will publish your new gem version to rubygems.org via [Trusted Publishing](https://guides.rubygems.org/trusted-publishing/). This workflow must be approved by a member of the Ruby and Rails Infrastructure team at Shopify before it will run. Once it is approved, it will automatically publish a new gem version to rubygems.org and create a new GitHub release.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Shopify/rbi. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).

## Code of Conduct

Everyone interacting in this project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).
