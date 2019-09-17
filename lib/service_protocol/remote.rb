# frozen_string_literal: true

require 'request_store'

module ServiceProtocol
  # RPC call to another app
  # response = Remote.call('content:items/get', id: 1)
  class Remote
    attr_accessor :endpoint, :context, :meta, :response

    # Error
    class Error < StandardError
      attr_reader :endpoint, :context, :meta

      def initialize(endpoint, context, meta)
        @endpoint = endpoint
        @context = context
        @meta = meta
        super("#{endpoint} failed: #{context.errors.inspect}")
      end
    end

    class << self
      # @param [String] endpoint 'service_name:operation', 'service_name:namespaced/operation'
      # @param [Hash] context
      # @param [Hash] any meta to pass through to the other service. Defaults
      #   (user_id, tenant_id will be mixed in automatically)
      # @return [Entity] with context response
      def call(endpoint, context = {}, meta = {})
        new(endpoint, context, meta).call
      end

      def call!(endpoint, context = {}, meta = nil)
        response = meta ? call(endpoint, context, meta) : call(endpoint, context)

        raise Error.new(endpoint, response, meta || {}) if response.failure?

        response
      end

      def adapter
        @adapter ||= begin
                       kind = ENV['SERVICE_PROTOCOL'] || 'web'
                       ServiceProtocol.constantizer("service_protocol/#{kind}_client")
                     rescue NameError
                       ServiceProtocol.constantizer("service_protocol/#{kind}/client")
                     end
      end
    end

    #
    # Instance Methods
    #

    # See {Remote.call} for parameters
    def initialize(endpoint, context, meta = {})
      resolver = ServiceProtocol.configuration.resolver || ->(endpoint) { endpoint }
      @endpoint = resolver.call(endpoint)
      @context = context.to_h
      @meta = request_store_meta.merge(meta.to_h)
    end

    # @return [Entity] with context response
    def call
      @response = adapter.new(endpoint, context, meta).call
      Entity.context response
    end

    private

    def adapter
      self.class.adapter
    end

    def request_store_meta
      h = RequestStore.store.dup
      [:logstasher_request_context, :logstasher_data].each { |k| h.delete(k) }

      # @hack to fix pact issues between sub services.
      if environment == 'test'
        h = {
          api_version: nil, super: false, request_id: '988ba439-9a1e-4994-91f2-82d03e53f26f',
          segment_id: '80d504426a8da30d', trace_id: '1-5c253efe-83ec9ef9e3fd686f9c82f4f9'
        }.merge(h)
      end

      h
    end

    def environment
      ENVIRONMENT
    rescue NameError
      'development'
    end
  end

  # @depreciated in 2.0.0
  RemoteAction = Remote
end
