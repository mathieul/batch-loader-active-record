# Batch Loader - Active Record #

[![Build Status](https://travis-ci.org/mathieul/batch-loader-active-record.svg?branch=master)](https://travis-ci.org/mathieul/batch-loader-active-record)
[![Gem Version](https://badge.fury.io/rb/batch-loader-active-record.svg)](https://badge.fury.io/rb/batch-loader-active-record)

This gem allows to leverage the awesome [batch-loader gem](https://github.com/exAspArk/batch-loader) to generate lazy Active Record relationships without any boilerplate.

It is not intended to be used for all associations though, but only where necessary. It should be used as a complement to vanilla batch loaders written directly using [batch-loader gem](https://github.com/exAspArk/batch-loader).

**This gem is in active deployment and is likely not yet ready to be used on production.**


## Description

This gem has a very simple implementation and delegates all batch loading responsibilities (used to avoid N+1 calls to the database) to the [batch-loader gem](https://github.com/exAspArk/batch-loader). It allows to generate a lazy association accessor with a simple statement: `association_accessor :association_name`.

Note that it doesn't yet support all cases handled by Active Record associations, refer to the [CHANGELOG](https://github.com/mathieul/batch-loader-active-record/blob/master/CHANGELOG.md) to know what is supported and what is not.

It is also possible to use one of the macros below in replacement of the original Active Record macro to both declare the association and trigger a lazy association accessort in a single statement.

* `belongs_to_lazy`
* `has_one_lazy`
* `has_many_lazy`
* `has_and_belongs_to_many_lazy`

As soon as your lazy association accessor needs to do more than fetch all records of an association (using a scope or not), you're going to want to directly use the batch-loader gem. For more details on N+1 queries read the [batch-loader gem README](https://github.com/exAspArk/batch-loader/#why).

For example let's imagine a post which can have many comments:

```ruby
class Post < ActiveRecord::Base
  include BatchLoaderActiveRecord
  has_many :comments
  association_accessor :comments
end

class Comment < ActiveRecord::Base
  belongs_to :post
end
```

Now we get a list of post objects and we want to fetch all the comments for each post. When we know in advance that we'll need the post comments, then Active Record query [#includes](http://api.rubyonrails.org/classes/ActiveRecord/QueryMethods.html#method-i-includes) will trigger a single query to fetch posts and comments.

But often we don't know in advance in the code responsible to fetch the posts if we'll need access to the comments as well. When implenting a GraphQL API for instance, the post resolver doesn't know if the comments are also part of the GraphQL query.Using `#includes` in this case would be wasteful and slower for the cases when we don't need the comments.

When using the lazy association accessor (i.e.: `post.comments_lazy`), a Batch Loader object is returned instead of a model relation and the query with the post id is buffered temporarily in the thread hash. No query to the database is executed yet. Calling the same association accessor on another post instance will add this post id to the list in the tread context. And so on until we access one of those Batch Loader objects returned. Only then is the database query executed and all Batch Loader objects are replaced by the records just fetched (not really replaced, they use delegation under the cover).

It is important to note that Active Record association accessors return relations which can be chained using the Active Record query API. But the lazy association accessors generated by `batch-loader-active-record` return (for all intents and purposes) an active record instance or an array of active record instances which can't be chained.

To benefit from the query batching we must first collect the lazy associations for each model instance in our collection, and only then we can start using them to access their content. Accessing a lazy object too early triggers the database query too early. For instance using `#flat_map` to collect and use the lazy objects would fail as `#flat_map` does access each element of the collection immediately in order to flatten the result.


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

Include the `BatchLoaderActiveRecord` module at the beginning of the model classes where lazy associations are needed, and use one of the lazy class macros to declare all lazy associations.

### Belongs To ###

Consider the following data model:

```ruby
class Post < ActiveRecord::Base
  has_many :comments
end

class Comment < ActiveRecord::Base
  include BatchLoaderActiveRecord
  belongs_to_lazy :post
end
```

We need to know the `post` owning each instance of `comments`:

```ruby
posts = comments.map(&:post_lazy)
# no DB query executed yet
posts.map(&:author_first_name)
# DB query was executed
# => ["Jane", "Anne", ...]
```

### Has One ###

Consider the following data model:

```ruby
class Account < ActiveRecord::Base
  include BatchLoaderActiveRecord
  has_one_lazy :affiliate
end

class Affiliate < ActiveRecord::Base
  belongs_to :account
end
```

Fetching all affiliates for the accounts who do have one affiliate:

```ruby
affiliates = accounts.map(&:affiliate_lazy)
# no DB query executed yet
affiliates.first.name
# DB query was executed
affiliates.compact
# => [#<Affiliate id: 123>, #<Affiliate id: 456>]
```

### Has Many ###

Consider the following data model:

```ruby
class Contact < ActiveRecord::Base
  include BatchLoaderActiveRecord
  has_many_lazy :phone_numbers
end

class PhoneNumber < ActiveRecord::Base
  belongs_to :contact
  scope :enabled, -> { where(enabled: true) }
end
```

This time we want the list of phone numbers for a collection of contacts.

```ruby
contacts.map(&:phone_numbers_lazy).flatten
```

It is also possible to apply scopes and conditions to a lazy has_many association. For instance if we want to only fetch enabled phone numbers in the example above, you would specify the scope like so:

```ruby
contacts.map { |contact| contact.phone_numbers_lazy(PhoneNumber.enabled) }.flatten
```


### Has Many :through ###

Consider the following data model with a has-many association going through another has-many-through association. Agents can have many phones they use to call providers:

```ruby
class Agent < ActiveRecord::Base
  include BatchLoaderActiveRecord
  has_many :phones
  has_many_lazy :providers, through: :phones
end

class Phone < ActiveRecord::Base
  belongs_to :agent
  has_many :calls
  has_many :providers, through: :calls
end

class Call < ActiveRecord::Base
  belongs_to :provider
  belongs_to :phone
end

class Provider < ActiveRecord::Base
  has_many :calls
end
```

We want to fetch the list of providers who were called by a list of agents:

```ruby
agents.map(&:providers_lazy).uniq
```

This would trigger this query for the collection of agents with ids 4212, 265 and 2309:

```sql
SELECT providers.*, agents.ID AS _instance_id
FROM providers
INNER JOIN calls ON calls.provider_id = providers.ID
INNER JOIN phones ON phones.ID = calls.phone_id
INNER JOIN agents ON agents.ID = phones.agent_id
WHERE (agents. ID IN(4212, 265, 2309))
```

### Has And Belongs To Many ###

Consider the following data model:

```ruby
class User < ActiveRecord::Base
  include BatchLoaderActiveRecord
  has_and_belongs_to_many :roles
  association_accessor :roles
end

class Role < ActiveRecord::Base
  has_and_belongs_to_many :users
end
```

This time we want the list of roles for a collection of users.

```ruby
users.map(&:roles_lazy).flatten
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mathieul/batch-loader-active-record. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the BatchLoaderActiveRecord project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/mathieul/batch-loader-active-record/blob/master/CODE_OF_CONDUCT.md).
