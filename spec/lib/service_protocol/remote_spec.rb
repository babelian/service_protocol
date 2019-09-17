# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ServiceProtocol::RemoteAction do
  let(:endpoint) { 'name:namespace/operation' }

  let(:context) do
    { data: 1 }
  end

  let(:meta) do
    { meta: 1 }
  end

  let(:fake_subject) do
    OpenStruct.new(call: 'done')
  end

  describe '.call' do
    let(:call) { described_class.call(endpoint, context) }

    before do
      allow(described_class).to receive(:new).with(endpoint, context, {}).and_return(fake_subject)
    end

    it 'works' do
      expect(call).to eq(fake_subject.call)
    end
  end

  describe '#call!' do
    it 'raises an Remote::Error if the response is a failure'
  end

  describe '.new' do
    describe 'endpoint resolver' do
      let(:example_endpoint) { 'api.service_protocol/endpoint_name' }

      let(:resolved_endpoint) do
        described_class.new(example_endpoint, {}, {}).endpoint
      end

      it 'by default passes through' do
        expect(resolved_endpoint).to eq(example_endpoint)
      end

      it 'can be customized via ServiceProtocol.configuration.resolver proc' do
        ServiceProtocol.configure do |config|
          config.resolver = ->(o) { o.sub('endpoint_name', 'new_name') }
        end
        expect(resolved_endpoint).to eq 'api.service_protocol/new_name'
      end
    end
  end

  describe 'integration with Proxy' do
    # TestOperation
    class TestOperation
      class << self
        attr_accessor :allow_remote

        def call(context)
          { equals: context[:one] + context[:two] }
        end
      end
    end

    module NameService
      class TestOperation < ::TestOperation
      end
    end

    let(:endpoint) { 'name:test_operation' }

    let(:context) do
      described_class.call(endpoint, one: 1, two: 2)
    end

    let(:configure_namespace) do
      ServiceProtocol.configure do |config|
        config.resolver = lambda do |op|
          service, path = op.split(':')
          "#{service}:#{service}_service/#{path}"
        end
      end
    end

    before do
      ENV['SERVICE_PROTOCOL'] = 'base'
      RequestStore.store.merge!(user_id: 1, tenant_id: 1)
      TestOperation.allow_remote = true
    end

    after do
      expect(RequestStore[:user_id]).to eq(nil)
    end

    describe 'meta checks' do
      it 'works when user_id and tenant_id are set' do
        expect(context.equals).to eq(3)
      end

      it 'raises error when meta missing' do
        RequestStore.store[:tenant_id] = nil
        expect { context }.to raise_error(/Meta missing/)
      end
    end

    describe 'can do batch operations' do
      let(:context) do
        described_class.call(
          'name:$batch',
          requests: {
            one: { operation: 'test_operation', params: { one: 1, two: 2 } },
            two: { operation: 'test_operation', params: { one: 3, two: 4 } }
          }
        )
      end

      it 'works' do
        expect(context.responses[:one][:equals]).to eq 3
        expect(context.responses[:two][:equals]).to eq 7
      end

      it 'works with namespaces' do
        configure_namespace
        expect(context.responses[:one][:equals]).to eq 3
      end
    end

    it 'filters output'

    # it 'raises if internal' do
    #   TestOperation.allow_remote = false
    #   expect { context.warn }.to raise_error(/remote/)
    # end

    it 'as_json options'
  end
end
