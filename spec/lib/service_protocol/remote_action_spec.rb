# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ServiceProtocol::RemoteAction do
  let(:operation) { 'name:namespace/action' }

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
    let(:call) { described_class.call(operation, context) }

    before do
      allow(described_class).to receive(:new).with(operation, context, {}).and_return(fake_subject)
    end

    it 'works' do
      expect(call).to eq(fake_subject.call)
    end
  end

  describe '#call!' do
    it 'raises an RemoteAction::Error if the response is a failure'
  end

  describe '.new' do
    describe 'operation resolver' do
      let(:example_operation) { 'api.service_protocol/operation_name' }

      let(:resolved_operation) do
        described_class.new(example_operation, {}, {}).operation
      end

      it 'by default passes through' do
        expect(resolved_operation).to eq(example_operation)
      end

      it 'can be customized via ServiceProtocol.configuration.resolver proc' do
        ServiceProtocol.configure do |config|
          config.resolver = ->(o) { o.sub('operation_name', 'new_name') }
        end
        expect(resolved_operation).to eq 'api.service_protocol/new_name'
      end
    end
  end

  describe 'integration with ProxyAction' do
    # TestAction
    class TestAction
      class << self
        attr_accessor :allow_remote

        def call(context)
          { equals: context[:one] + context[:two] }
        end
      end
    end

    module NameService
      class TestAction < ::TestAction
      end
    end

    let(:operation) { 'name:test_action' }

    let(:context) do
      described_class.call(operation, one: 1, two: 2)
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
      TestAction.allow_remote = true
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

    describe 'can do batch actions' do
      let(:context) do
        described_class.call(
          'name:$batch',
          requests: {
            one: { action: 'test_action', params: { one: 1, two: 2 } },
            two: { action: 'test_action', params: { one: 3, two: 4 } }
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
    #   TestAction.allow_remote = false
    #   expect { context.warn }.to raise_error(/remote/)
    # end

    it 'as_json options'
  end
end
