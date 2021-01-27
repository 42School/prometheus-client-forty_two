# Prometheus::Client::FortyTwo

A configurable Collector middleware for prometheus-client at 42.

## Installation

If you're using [Bundler](https://bundler.io/) add this line to your `Gemfile`.

```ruby
gem 'prometheus-client-forty_two'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install prometheus-client-forty_two

## Overview

The Prometheus Ruby Client gem comes with nice standard middlewares to collect
simple metrics on routes visited on the app, but it fails in some specific cases:

1.  Non-numeric, non-uuid identifiers are not cleaned up.
2.  When static files are served by the server, those queries are collected.

This gem offers another Collector that can be customized to:

1.  Clean custom identifiers.

        use Prometheus::Client::FortyTwo::Middleware::Collector, 
            specific_id_stripper: lambda { |path|
              path
                .gsub(%r{/users/[^/]*}, '/users/:name')
                .gsub(%r{/[en|es|fr]/}, '/:locale/')
            }

        # '/en/users/albert/posts/10/articles'
        # '/fr/users/julie/posts/223/articles'
        # '/es/users/zoe/posts/68/articles'
        # would be stripped as one route:
        # '/:locale/users/:name/posts/:id/articles'

2.  Not collect metrics on static files.

        use Prometheus::Client::FortyTwo::Middleware::Collector,
            static_files_path: File.join(File.dirname(__FILE__), 'public')

        # this will recursively list all files in the `/public` directory
        # and not collect any metrics on those

See [Prometheus Client](https://github.com/prometheus/client_ruby) to build your
own metrics.

## Usage

```ruby
# config.ru

require 'rack'
require 'prometheus/client/forty_two'
require 'prometheus/middleware/exporter'

use Rack::Deflater
use Prometheus::Client::FortyTwo::Middleware::Collector,
  # TODO: add your configuration for the collector
use Prometheus::Middleware::Exporter

run ->(_) { [200, {'Content-Type' => 'text/html'}, ['OK']] }
```

## Development

### Using docker

This gem has been built for ruby 2.2.3 compatibility. Since this version is now
deprecated, and therefore difficult to install on a recent system, this
repository has been provided a `Dockerfile` and a `docher-compose.yml` to work
inside a container.

To build the container:

```sh
$ docker-compose build gem
```

To run commands in the container:

```sh
$ docker-compose run gem {COMMAND}
```

To run as session in the container:

```sh
$ docker-compose run gem bash
```

See next section for development commands

### Directly on your system

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`, and then
run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at [42School/prometheus-client-forty_two](https://github.com/42School/prometheus-client-forty_two).

This project is intended to be a safe, welcoming space for collaboration, and
contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org)
code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

