# frozen_string_literal: true

require 'securerandom'

module ServiceProtocol
  # @abstract
  class BaseClient
    class TimeoutException < RuntimeError; end

    attr_reader :endpoint, :params, :meta, :queued

    #
    # Class Methods
    #

    class << self
      # @param [String] endpoint, eg 'api.service_name:namespaced/operation'
      # @param [Hash] params
      # @param [Hash] meta
      # @return [Hash] with stringified/json keys
      def call(endpoint, params, meta)
        new(endpoint, params, meta).call
      end

      def queue(endpoint, params, meta)
        new(endpoint, params, meta).queue
        {}
      end
    end

    #
    # Instance Methods
    #

    def initialize(endpoint, params, meta)
      @endpoint = endpoint
      @params = params
      @meta = meta
    end

    # @abstract, but used in specs to test {Remote} {Proxy} integration.
    def call
      require 'service_protocol/proxy'
      Proxy.call(operation, params, meta)
    end

    def queue
      @queued = true
      call
    end

    private

    # namespaced/operation
    def operation
      endpoint.split(':').last.split('.').last
    end

    def call_id
      @call_id ||= SecureRandom.uuid
    end

    # api.service
    def routing
      endpoint.split(':').first
    end

    # service
    def service_name
      routing.split('.').last
    end

    def token
      ENV['SERVICE_PROTOCOL_TOKEN'] || raise("No ENV['SERVICE_PROTOCOL_TOKEN'] set")
    end
  end
end
