# frozen_string_literal: true

require 'securerandom'

module ServiceProtocol
  # @abstract
  class BaseClient
    class TimeoutException < Exception; end

    attr_reader :operation, :params, :meta, :queued

    class << self
      def call(operation, params, meta)
        new(operation, params, meta).call
      end

      def queue(operation, params, meta)
        new(operation, params, meta).queue
        {}
      end
    end

    def initialize(operation, params, meta)
      @operation = operation
      @params = params
      @meta = meta
    end

    # @abstract and used in specs to test {RemoteAction} {ProxyAction} integration
    def call
      require 'service_protocol/proxy_action'
      ProxyAction.call(action, params, meta)
    end

    def queue
      @queued = true
      call
    end

    private

    # namespaced/action
    def action
      operation.split(':').last.split('.').last
    end

    def call_id
      @call_id ||= SecureRandom.uuid
    end

    # api.service
    def routing
      operation.split(':').first
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