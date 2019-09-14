# frozen_string_literal: true

require 'service_protocol/proxy_action'
require 'service_protocol/redis_connection'

module ServiceProtocol
  # RedisServer
  class RedisServer
    include RedisConnection
    attr_reader :queue_name, :timeout

    def initialize(queue_name, timeout: nil)
      @queue_name = queue_name
      @timeout = timeout || 0
    end

    def run
      puts "Starting #{queue_name}"
      redis_queue.process(false, timeout) do |raw_request|
        puts "processing: #{raw_request}"
        run_one(raw_request)
        true
      end
    end

    def run!
      redis_queue.clear(true)
      run
    end

    private

    attr_reader :raw_request

    def run_one(raw_request)
      @request = @response = nil

      if @raw_request = raw_request
        authenticate
        response
        reply
      end
    rescue StandardError => e
      puts e.inspect
      redis_error(e)
    end

    def authenticate
      ENV['SERVICE_PROTOCOL_TOKEN'].split(',').include?(token) || raise('Authentication Error')
    end

    def token
      request[:meta][:service_protocol_token]
    end

    def action
      request[:action]
    end

    def params
      request[:params] || {}
    end

    def meta
      request[:meta] || {}
    end

    def reply_to
      request[:reply_to]
    end

    def request
      @request ||= JSON.parse(@raw_request, symbolize_names: true)
    end

    def response
      @response ||= ServiceProtocol::ProxyAction.call(action, params, meta)
    end

    #
    # Redis
    #

    def reply
      return unless reply_to
      raw_response = JSON.dump response

      redis.multi do
        redis.rpush reply_to, raw_response
        redis.expire reply_to, 30
      end

      true
    end
  end
end