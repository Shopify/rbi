# Rbi

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/rbi`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rbi'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install rbi

## Usage

TODO: Write usage instructions here

### Using a .netrc file

RBI supports reading credentials from a netrc file (defaulting to `~/.netrc`).

Specify these lines in your netrc:

```
machine api.github.com
  login defunkt
  password <your 40 char token>
```

Then run the `rbi` command with the `--netrc` option. `--netrc-file` also be specified to read another file than `~/.netrc`:

```
rbi --netrc --netrc-file /path/to/my/netrc
```

If the `--netrc-file` isn't specified, RBI will try to find the netrc file from the environment by reading the following variables in order:

1. `RBI_NETRC`
2. `OCTOKIT_NETRC`
3. `NETRC`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

This repo uses itself (`rbi`) to retrieve and generate gem RBIs. You can run `dev rbi` to update local gem RBIs with RBIs from the central repo.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/rbi. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/rbi/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Rbi project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/rbi/blob/master/CODE_OF_CONDUCT.md).
