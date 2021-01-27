require 'spec_helper'

class FunkyException < StandardError; end

describe Prometheus::FortyTwo do
  it 'has a version number' do
    expect(Prometheus::FortyTwo::VERSION).not_to be nil
  end

  describe Prometheus::FortyTwo::Collector do
    let(:code) { :success }
    let(:request_method) { 'POST' }
    let(:script_name) { 'SCRIPT_NAME' }
    let(:uuid) { SecureRandom.uuid }
    let(:path_info) { "/blah/123/something/#{uuid}/users/123lautaro/b" }
    let(:metrics_prefix) { 'whatever' }
    let(:duration) { 0.2 }

    let(:cleaned_up_path) { '/blah/:id/something/:uuid/users/123lautaro/b' }

    let(:app) { double(:app) }
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

    def fake_env(overrides = {})
      double(:env).tap do |env|
        {
          'REQUEST_METHOD' => request_method,
          'SCRIPT_NAME' => script_name,
          'PATH_INFO' => path_info
        }
          .merge(overrides)
          .each do |key, value|
            allow(env).to receive(:[]).with(key).and_return(value)
          end
      end
    end

    before(:each) do
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

        allow(app).to receive(:call) do
          sleep(duration)
          response
        end

        allow(requests_registry).to receive(:increment)
        allow(durations_registry).to receive(:observe)
      end

      context 'without specific id strippers' do
        it 'collects a success like the original collector' do
          collector = Prometheus::FortyTwo::Collector.new(
            app,
            registry: registry,
            metrics_prefix: metrics_prefix
          )

          expect(app).not_to have_received(:call)

          env = fake_env
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
              be_within(0.001).of(duration),
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

      context 'with specific id strippers' do
        context 'the stripper is not buggy' do
          let(:cleaned_up_path) { '/blah/:id/something/:uuid/users/:id/b' }

          it 'strips specific ids' do
            collector = Prometheus::FortyTwo::Collector.new(
              app,
              registry: registry,
              metrics_prefix: metrics_prefix,
              specific_id_stripper: lambda { |path|
                path.gsub(%r{/users/[^/]*}, '/users/:id')
              }
            )

            expect(app).not_to have_received(:call)

            env = fake_env
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
                be_within(0.001).of(duration),
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

        context 'the stripper is buggy' do
          let(:exception) { FunkyException.new('ooops') }

          it 'does not fail, only uses the standard stripper' do
            collector = Prometheus::FortyTwo::Collector.new(
              app,
              registry: registry,
              metrics_prefix: metrics_prefix,
              specific_id_stripper: -> { raise exception }
            )

            expect(app).not_to have_received(:call)

            env = fake_env
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
                be_within(0.001).of(duration),
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
      end

      context 'with static files to ignore' do
        let(:ignore_path) { '/a/fictional/path' }

        let(:static_files) do
          [
            '/robot.txt',
            '/whatever/you_desire.ico',
            '/image/your_mule.jpg'
          ]
        end

        before(:each) do
          allow(Prometheus::FortyTwo::Collector)
            .to receive(:find_static_files!)
            .with(ignore_path)
            .and_return(static_files)
        end

        it 'ignores static files' do
          collector = Prometheus::FortyTwo::Collector.new(
            app,
            registry: registry,
            metrics_prefix: metrics_prefix,
            static_files_path: ignore_path
          )

          expect(app).not_to have_received(:call)

          static_files.each do |path|
            env = fake_env('PATH_INFO' => path)
            result = collector.call(env)

            expect(app).to have_received(:call)
              .with(env)

            expect(result).to eq response
          end

          expect(requests_registry).not_to have_received(:increment)
          expect(durations_registry).not_to have_received(:observe)

          expect(app).to have_received(:call)
            .exactly(3).times

          path = '/not_a_static.file'
          env = fake_env('PATH_INFO' => path)
          result = collector.call(env)

          expect(app).to have_received(:call)
            .with(env)

          expect(result).to eq response

          expect(requests_registry).to have_received(:increment)
            .once
          expect(requests_registry).to have_received(:increment)
            .with(
              labels: {
                code: code.to_s,
                method: request_method.downcase,
                path: path
              }
            )
          expect(durations_registry).to have_received(:observe)
            .once
          expect(durations_registry).to have_received(:observe)
            .with(
              be_within(0.001).of(duration),
              labels: {
                method: request_method.downcase,
                path: path
              }
            )
        end
      end
    end

    context 'when the request fails' do
      let(:exception) { FunkyException.new('aaargh') }

      before(:each) do
        allow(app).to receive(:call)
          .and_raise(exception)

        allow(exceptions_registry).to receive(:increment)
      end

      context 'without specific id strippers' do
        it 'collects a failure like the original collector' do
          collector = Prometheus::FortyTwo::Collector.new(
            app,
            registry: registry,
            metrics_prefix: metrics_prefix
          )

          expect(app).not_to have_received(:call)

          env = fake_env
          expect { collector.call(env) }
            .to raise_error(exception)

          expect(exceptions_registry).to have_received(:increment)
            .once
          expect(exceptions_registry).to have_received(:increment)
            .with(labels: { exception: 'FunkyException' })

          expect(app).to have_received(:call)
            .once
          expect(app).to have_received(:call)
            .with(env)
        end
      end

      context 'with specific id strippers' do
        it 'collects a failure like the original collector' do
          collector = Prometheus::FortyTwo::Collector.new(
            app,
            registry: registry,
            metrics_prefix: metrics_prefix,
            specific_id_stripper: lambda { |path|
              path.gsub(%r{/users/[^/]*}, '/users/:id')
            }
          )

          expect(app).not_to have_received(:call)

          env = fake_env
          expect { collector.call(env) }
            .to raise_error(exception)

          expect(exceptions_registry).to have_received(:increment)
            .once
          expect(exceptions_registry).to have_received(:increment)
            .with(labels: { exception: 'FunkyException' })

          expect(app).to have_received(:call)
            .once
          expect(app).to have_received(:call)
            .with(env)
        end
      end

      context 'with static files to ignore' do
        let(:ignore_path) { '/a/fictional/path' }

        let(:static_files) do
          [
            '/robot.txt',
            '/whatever/you_desire.ico',
            '/image/your_mule.jpg'
          ]
        end

        before(:each) do
          allow(Prometheus::FortyTwo::Collector)
            .to receive(:find_static_files!)
            .with(ignore_path)
            .and_return(static_files)
        end

        it 'ignores static files' do
          collector = Prometheus::FortyTwo::Collector.new(
            app,
            registry: registry,
            metrics_prefix: metrics_prefix,
            static_files_path: ignore_path
          )

          expect(app).not_to have_received(:call)

          static_files.each do |path|
            env = fake_env('PATH_INFO' => path)
            expect { collector.call(env) }
              .to raise_error(exception)

            expect(app).to have_received(:call)
              .with(env)
          end

          expect(exceptions_registry).not_to have_received(:increment)

          expect(app).to have_received(:call)
            .exactly(3).times

          path = '/not_a_static.file'
          env = fake_env('PATH_INFO' => path)
          expect { collector.call(env) }
            .to raise_error(exception)

          expect(app).to have_received(:call)
            .with(env)

          expect(exceptions_registry).to have_received(:increment)
            .once
          expect(exceptions_registry).to have_received(:increment)
            .with(labels: { exception: 'FunkyException' })
        end
      end
    end

    context 'when the static files discovery fails' do
      let(:exception) { FunkyException.new('wow, dude!') }
      let(:ignore_path) { '/a/fictional/path' }
      let(:response) { double(:response) }

      before(:each) do
        allow(response).to receive(:first)
          .and_return(code)

        allow(app).to receive(:call) do
          sleep(duration)
          response
        end

        allow(requests_registry).to receive(:increment)
        allow(durations_registry).to receive(:observe)

        allow(Prometheus::FortyTwo::Collector)
          .to receive(:find_static_files!)
          .with(ignore_path)
          .and_raise(exception)
      end

      it 'starts all the same and collects all requests' do
        collector = Prometheus::FortyTwo::Collector.new(
          app,
          registry: registry,
          metrics_prefix: metrics_prefix,
          static_files_path: ignore_path
        )

        env = fake_env
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
            be_within(0.001).of(duration),
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
  end
end
