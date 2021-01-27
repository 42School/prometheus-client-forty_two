require 'prometheus/client/forty_two/version'
require 'prometheus/middleware/collector'
require 'find'

module Prometheus
  module Client
    module FortyTwo
      module Middleware
        # Collector is a Rack middleware that improves on the basic
        # collector provided by the prometheus-client gem.
        #
        # By default, the original collector will strip routes of their
        # ids assuming they are either numeric or uuids. Set the
        # `:specific_id_stripper` option to provide a specific method
        # to strip ids from urls and replace them by a generic label.
        # The lambda will receive the route as a string before the
        # default stripper strips the ids from it, and should return
        # the cleaned up route.
        #
        #   use(
        #     Prometheus::Client::FortyTwo::Middleware::Collector,
        #     specific_id_stripper: lambda { |path|
        #       path
        #         .gsub(%r{/users/[^/]*}, '/users/:name')
        #         .gsub(%r{/[en|es|fr]/}, '/:locale/')
        #     }
        #   )
        #
        #   # '/en/users/albert/posts/10/articles'
        #   # '/fr/users/julie/posts/223/articles'
        #   # '/es/users/zoe/posts/68/articles'
        #   # would be stripped as:
        #   # '/:locale/users/:name/posts/:id/articles'
        #
        # If the cleaner fails, the collector will not and only use the
        # original strip function.
        #
        #
        # When your rails server serves static files, those requests
        # are not necessarily very relevant to your stats. Set the
        # `:static_files_path` option to make the middleware list those
        # files on startup and ignore them.
        # If the directory does not exist or an exception is raised
        # when discovering it, the Collector will just ignore it and
        # start anyways.
        #
        #   use(
        #     Prometheus::Client::FortyTwo::Middleware::Collector,
        #     static_files_path: File.join(File.dirname(__FILE__), 'public')
        #   )
        #
        #   # all routes pointing to /public will be ignored
        class Collector < Prometheus::Middleware::Collector
          def initialize(app, options = {})
            super

            @static_files = self.class.find_static_files(options[:static_files_path])
            @specific_id_stripper = options[:specific_id_stripper] || ->(path) { path }
          end

          def call(env)
            return @app.call(env) if @static_files.include?(env['PATH_INFO'])

            super
          end

          protected

          def strip_ids_from_path(path)
            stripped_path = super
            begin
              @specific_id_stripper.call(stripped_path)
            rescue StandardError
              stripped_path
            end
          end

          class << self
            def find_static_files(path)
              find_static_files!(path)
            rescue StandardError
              []
            end

            def find_static_files!(path)
              return [] unless path

              Find
                .find(path)
                .select { |f| File.file?(f) }
                .map { |f| f.gsub(%r{\A\./}, '/') }
            end
          end
        end
      end
    end
  end
end
