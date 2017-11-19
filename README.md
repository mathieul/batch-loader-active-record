# Batch Loader - Active Record #

[![Build Status](https://travis-ci.org/mathieul/batch-loader-active-record.svg?branch=master)](https://travis-ci.org/mathieul/batch-loader-active-record)
[![Gem Version](https://badge.fury.io/rb/batch-loader-active-record.svg)](https://badge.fury.io/rb/batch-loader-active-record)

This gem allows to leverage the awesome [batch-loader gem](https://github.com/exAspArk/batch-loader) to generate lazy Active Record relationships without any boilerplate.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'batch-loader-active-record'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install batch-loader-active-record

## Usage

This is a very simple gem which just contains a mixin to include and give access to class methods for each association kind:

* `belongs_to_lazy`
* `has_one_lazy`
* `has_many_lazy`

You use those generators in replacement of the original Active Record association class methods.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mathieul/batch-loader-active-record. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the BatchLoaderActiveRecord project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/mathieul/batch-loader-active-record/blob/master/CODE_OF_CONDUCT.md).
