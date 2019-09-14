# frozen_string_literal: true

require 'request_store'
require 'ruby_extensions/all'

module ServiceProtocol
  # RPC call to another app
  # response = RemoteAction.call('content:items/get', id: 1)
  class RemoteAction
    attr_accessor :operation, :context, :meta, :response

    # Error
    class Error < StandardError
      attr_reader :operation, :context, :meta

      def initialize(operation, context, meta)
        @operation = operation
        @context = context
        @meta = meta
        super("#{operation} failed: #{context.errors.inspect}")
      end
    end

    class << self
      # @param [String] operation 'service:action', 'service:namespaced/action'
      # @param [Hash] context
      # @param [Hash] any meta to pass through to the other service. Defaults
      #   (user_id, tenant_id will be mixed in automatically)
      # @return [ValueObject] with context response
      def call(operation, context = {}, meta = {})
        new(operation, context, meta).call
      end

      def call!(operation, context = {}, meta = nil)
        response = meta ? call(operation, context, meta) : call(operation, context)

        raise Error.new(operation, response, meta || {}) if response.failure?

        response
      end

      def adapter
        @adapter ||= begin
          kind = ENV['SERVICE_PROTOCOL'] || 'web'
          path = "service_protocol/#{kind}_client"
          require path
          ServiceProtocol.constantizer(path)
        end
      end
    end

    #
    # Instance Methods
    #

    # See {RemoteAction.call} for parameters
    def initialize(operation, context, meta = {})
      resolver = ServiceProtocol.configuration.resolver
      @operation = resolver ? resolver.call(operation) : operation
      @context = context.to_h
      @meta = request_store_meta.merge(meta.to_h)
    end

    # @return [ValueObject] with context response
    def call
      @response = adapter.new(operation, context, meta).call
      ValueObject.context response
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
end