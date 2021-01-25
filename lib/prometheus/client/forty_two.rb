require 'prometheus/client/forty_two/version'
require 'prometheus/middleware/collector'

module Prometheus
  module Client
    module FortyTwo
      module Middleware
        class Collector < Prometheus::Middleware::Collector
        end
      end
    end
  end
end
