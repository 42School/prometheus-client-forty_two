require 'prometheus/client/forty_two/version'
require 'prometheus/middleware/collector'

module Prometheus
  module Client
    module FortyTwo
      module Middleware
        class Collector < Prometheus::Middleware::Collector
          def initialize(app, options = {})
            super

            @specific_id_stripper = options[:specific_id_stripper] || ->(path) { path }
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
        end
      end
    end
  end
end
