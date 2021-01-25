require 'spec_helper'

describe Prometheus::Client::FortyTwo do
  it 'has a version number' do
    expect(Prometheus::Client::FortyTwo::VERSION).not_to be nil
  end

  describe Prometheus::Client::FortyTwo::Middleware::Collector do
    let(:code) { :success }
    let(:request_method) { 'POST' }
    let(:script_name) { 'SCRIPT_NAME' }
    let(:uuid) { SecureRandom.uuid }
    let(:path_info) { "/blah/123/something/#{uuid}/or_other/123abc" }
    let(:metrics_prefix) { 'whatever' }

    let(:cleaned_up_path) { '/blah/:id/something/:uuid/or_other/123abc' }

    let(:app) { double(:app) }
    let(:env) { double(:env) }
    let(:registry) { double(:registry) }

    let(:requests_registry) { double(:requests_registry) }
    let(:durations_registry) { double(:durations_registry) }
    let(:exceptions_registry) { double(:exceptions_registry) }

    let(:requests_registry_params) do
      [
        :"#{metrics_prefix}_requests_total",
        {
          docstring: 'The total number of HTTP requests handled by the Rack application.',
          labels: %i[code method path]
        }
      ]
    end

    let(:durations_registry_params) do
      [
        :"#{metrics_prefix}_request_duration_seconds",
        {
          docstring: 'The HTTP response duration of the Rack application.',
          labels: %i[method path]
        }
      ]
    end

    let(:exceptions_registry_params) do
      [
        :"#{metrics_prefix}_exceptions_total",
        {
          docstring: 'The total number of exceptions raised by the Rack application.',
          labels: [:exception]
        }
      ]
    end

    before(:each) do
      allow(env).to receive(:[])
        .with('REQUEST_METHOD')
        .and_return(request_method)
      allow(env).to receive(:[])
        .with('SCRIPT_NAME')
        .and_return(script_name)
      allow(env).to receive(:[])
        .with('PATH_INFO')
        .and_return(path_info)

      allow(registry).to receive(:counter)
        .with(*requests_registry_params)
        .and_return(requests_registry)
      allow(registry).to receive(:counter)
        .with(*exceptions_registry_params)
        .and_return(exceptions_registry)
      allow(registry).to receive(:histogram)
        .with(*durations_registry_params)
        .and_return(durations_registry)
    end

    context 'when the request succeeds' do
      let(:response) { double(:response) }

      before(:each) do
        allow(response).to receive(:first)
          .and_return(code)

        allow(app).to receive(:call)
          .and_return(response)

        allow(requests_registry).to receive(:increment)
        allow(durations_registry).to receive(:observe)
      end

      it 'collects a success like the original collector' do
        collector =
          Prometheus::Client::FortyTwo::Middleware::Collector.new(
            app,
            registry: registry,
            metrics_prefix: metrics_prefix
          )

        expect(app).not_to have_received(:call)

        result = collector.call(env)

        expect(requests_registry).to have_received(:increment)
          .once
        expect(requests_registry).to have_received(:increment)
          .with(
            labels: {
              code: code.to_s,
              method: request_method.downcase,
              path: cleaned_up_path
            }
          )

        expect(durations_registry).to have_received(:observe)
          .once
        expect(durations_registry).to have_received(:observe)
          .with(
            be_within(0.1).of(0),
            labels: {
              method: request_method.downcase,
              path: cleaned_up_path
            }
          )

        expect(app).to have_received(:call)
          .once
        expect(app).to have_received(:call)
          .with(env)
        expect(result).to eq response
      end
    end

    context 'when the request fails' do
      let(:exception) { ArgumentError.new('aaargh') }

      before(:each) do
        allow(app).to receive(:call)
          .and_raise(exception)

        allow(exceptions_registry).to receive(:increment)
      end

      it 'collects a failure like the original collector' do
        collector =
          Prometheus::Client::FortyTwo::Middleware::Collector.new(
            app,
            registry: registry,
            metrics_prefix: metrics_prefix
          )

        expect(app).not_to have_received(:call)

        expect { collector.call(env) }
          .to raise_error(exception)

        expect(exceptions_registry).to have_received(:increment)
          .once
        expect(exceptions_registry).to have_received(:increment)
          .with(labels: { exception: 'ArgumentError' })

        expect(app).to have_received(:call)
          .once
        expect(app).to have_received(:call)
          .with(env)
      end
    end
  end
end
