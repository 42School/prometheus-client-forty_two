require 'prometheus/forty_two/version'
require 'prometheus/middleware/collector'
require 'find'

module Prometheus
  module FortyTwo
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
    #   # would be stripped as one route:
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
    #
    #
    # Some of your app routes might not be relevant to your stats either
    # (ie. /metrics, or /assets/**/* paths). Set the `:irrelevant_paths`
    # option to provide a method that will match paths you want to ignore.
    #
    #   use(
    #     Prometheus::Client::FortyTwo::Middleware::Collector,
    #     irrelevant_paths: labmda { |path|
    #       path == '/metrics' ||
    #       path =~ %r{\A/assets/}
    #     }
    #   )
    class Collector < Prometheus::Middleware::Collector
      def initialize(app, options = {})
        super

        @static_files = self.class.find_static_files(options[:static_files_path])
        @irrelevant_paths = options[:irrelevant_paths] || ->(_path) { false }
        @specific_id_stripper = options[:specific_id_stripper] || ->(path) { path }
      end

      def call(env)
        return @app.call(env) if ignore_path?(env['PATH_INFO'])

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

      def ignore_path?(path)
        @static_files.include?(path) || irrelevant_path?(path)
      end

      def irrelevant_path?(path)
        @irrelevant_paths.call(path)
      rescue StandardError
        false
      end

      class << self
        def find_static_files(path)
          find_static_files!(path)
        rescue StandardError
          []
        end

        def find_static_files!(path)
          return [] unless path

          path = path.gsub(%r{/+\z}, '')
          path_matcher = %r{\A#{Regexp.escape(path)}/}
          Find
            .find(path)
            .select { |f| File.file?(f) }
            .map { |f| f.gsub(path_matcher, '/') }
        end
      end
    end
  end
end
