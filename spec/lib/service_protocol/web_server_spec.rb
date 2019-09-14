# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ServiceProtocol::WebServer do
  let(:token) { '123' }
  let(:server) { Rack::MockRequest.new(described_class.new) }

  let(:env) do
    {
      'REMOTE_ADDR' => '127.0.0.1',
      'HTTP_X_SERVICE_PROTOCOL_TOKEN' => token,
      input: StringIO.new(request.to_json)
    }
  end

  let(:path) { '/test/action' }

  let(:request) do
    {
      params: { param: 1 },
      meta: { user_id: 2, tenant_id: 3 }
    }
  end

  let(:response) { server.post(path, env) }

  let(:status) { response.status }

  let(:body) do
    if response.body[0] == '{'
      JSON.parse(response.body, symbolize_names: true)
    else
      response.body
    end
  end

  module Test
    # Dummy Action
    class Action
      class << self
        def call(input)
          { params: input, meta: RequestStore.store, done: true }
        end
      end
    end
  end

  context '/health' do
    let(:path) { '/health' }

    it 'works' do
      expect(status).to eq 200
      expect(body).to eq('OK')
    end
  end

  context '/namespaced/action' do
    before do
      ENV['SERVICE_PROTOCOL_TOKEN'] = token
    end

    it 'authenticates' do
      env['HTTP_X_SERVICE_PROTOCOL_TOKEN'] = ''
      expect(status).to eq 401
    end

    it 'proxies' do
      expect(status).to eq 200
      expect(body).to eq request.merge(done: true)
    end

    it 'clears previous request' do
      # run first response
      response

      # generate second response
      request[:params][:param] = 4
      env[:input] = StringIO.new(request.to_json)
      response2 = JSON.parse(server.post(path, env).body, symbolize_names: true)

      expect(response2[:params]).to eq request[:params]
    end
  end

  context "ENV['SERVICE_PROTOCOL_PATH_PREFIX'] = '/prefix'" do
    before do
      ENV['SERVICE_PROTOCOL_PATH_PREFIX'] = '/prefix'
    end

    let(:path) { '/prefix/test/action' }

    it 'removes prefix' do
      expect(status).to eq(200)
      expect(body[:done]).to eq true
    end
  end
end