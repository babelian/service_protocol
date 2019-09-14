# frozen_string_literal: true

require 'service_protocol/base_client'
require 'service_protocol/redis_connection'
require 'json'

module ServiceProtocol
  # Redis based client for RPC requests
  class RedisClient < BaseClient
    include RedisConnection
    def call
      make_request
      wait_for_response
    rescue TimeoutException => e
      remove_from_queue
      raise e
    end

    #
    # Routing
    #

    alias queue_name routing

    def reply_to
      @reply_to ||= "#{queue_name}:rpc:#{call_id}"
    end

    def timeout
      @timeout ||= meta[:timeout] || 0
    end

    #
    # Data
    #

    def request
      h = { action: action, params: params, meta: meta }
      h[:meta][:service_protocol_token] = token
      h[:reply_to] = reply_to unless queued
      h
    end

    def response
      JSON.parse(raw_response, symbolize_names: true)
    end

    private

    def raw_request
      @raw_request ||= JSON.dump(request)
    end

    attr_reader :raw_response

    #
    # Redis Commands
    #

    def make_request
      redis_queue << raw_request
    end

    def wait_for_response
      return {} if queued

      _message_queue, @raw_response = redis.blpop(reply_to, timeout)
      raise TimeoutException if raw_response.nil?
      response
    end

    def remove_from_queue
      # stale request cleanup
      redis.lrem queue_name, 0, raw_request
    end
  end
end