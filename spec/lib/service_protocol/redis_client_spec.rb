# frozen_string_literal: true

require 'spec_helper'

require 'request_store'

RSpec.describe ServiceProtocol::RedisClient do
  module TestNamespace
    # Test class
    class TestAction
      class << self
        include ServiceProtocol::RedisConnection

        def call(params)
          if RequestStore[:operator]
            { equals: params[:one].send(RequestStore[:operator], params[:two]) }
          else
            sleep(0.25)
            redis.set params[:key], params[:value]
            {}
          end
        end
      end
    end
  end

  let(:queue_name) { 'api.service' }
  let(:operation) { "#{queue_name}:test_namespace/test_action" }

  describe 'integration' do
    include ServiceProtocol::RedisConnection

    let(:server) { ServiceProtocol::RedisServer.new(queue_name) }

    let(:fork_server) do
      fork { server.run }
    end

    let(:default_meta) do
      { user_id: 1, tenant_id: 1 }
    end

    let(:meta) do
      default_meta
    end

    before do
      RequestStore.clear!
      redis.flushdb
      fork_server
    end

    after do
      sleep(1)
      expect_clean_db
      Process.kill(9, fork_server)
    end

    describe '.call' do
      let(:params) do
        { one: 1, two: 2 }
      end

      let(:meta) do
        default_meta.merge(operator: '+')
      end

      let(:context) do
        described_class.call(operation, params, meta)
      end

      it 'waits for a response' do
        expect(context).to eq(equals: 3)
      end

      it 'server does not cache requests and responses' do
        params[:one] = 2
        expect(context).to eq(equals: 4)
      end
    end

    describe '.queue' do
      let(:params) do
        { key: 'x', value: 'y' }
      end

      let(:context) do
        described_class.queue(operation, params, meta)
      end

      it 'process asyncronously' do
        expect(context).to eq({})

        expect(set_value).to eq(nil)
        sleep(1)
        expect(set_value).to eq(params[:value])
        redis.del params[:key]
      end

      private

      def set_value
        redis.get(params[:key])
      end
    end

    def expect_clean_db
      # expect(redis.lpop('api.service:processing')).to eq(nil)
      expect(redis.keys).to eq []
    end
  end
end
