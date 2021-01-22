lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'prometheus/client/forty_two/version'

Gem::Specification.new do |spec|
  spec.name          = 'prometheus-client-forty_two'
  spec.version       = Prometheus::Client::FortyTwo::VERSION
  spec.authors       = ['Michel Belleville']
  spec.email         = ['michel.belleville@gmail.com']

  spec.summary       = 'A configurable Collector middleware for prometheus-client at 42'
  spec.description   = <<-DESC.strip
    Using prometheus-client with non-standard routes (i.e. using non-hexadecimal ids) yields problematic results.
    This gem solves the problem offering a configurable Collector middleware.
  DESC
  spec.homepage      = 'https://github.com/42School/prometheus-client-forty_two'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'prometheus-client', '~> 2.1.0'

  spec.add_development_dependency 'bundler', '~> 1.13'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
