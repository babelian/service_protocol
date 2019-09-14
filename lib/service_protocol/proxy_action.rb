# frozen_string_literal: true

require 'logger'
require 'request_store'

module ServiceProtocol
  # Wrapper for receiving the RPC Request from the Server and calling the local Action
  class ProxyAction
    REQUIRED_META_KEYS = [:user_id, :tenant_id].freeze

    attr_reader :action, :context

    class << self
      def call(action, params, meta)
        add_meta_to_request_store(meta) do
          if action.include?('$batch')
            namespace = action.sub('$batch', '')
            params[:requests].values.each { |v| v[:action] = "#{namespace}#{v[:action]}" }
            batch(params)
          else
            new(action, params).call
          end
        end
      end

      private

      # merge meta into RequestStore
      def add_meta_to_request_store(meta)
        return yield if ServiceProtocol.configuration.local_requests

        RequestStore.begin!

        if REQUIRED_META_KEYS.any? { |k| (meta || {})[k].to_s.empty? }
          raise "Meta missing #{REQUIRED_META_KEYS.inspect}: #{meta.inspect}"
        end

        RequestStore.store.merge!(meta)

        yield
      ensure
        RequestStore.end!
        RequestStore.clear!
      end

      # See https://docs.microsoft.com/en-us/graph/json-batching for examples on extending
      # to include dependencies/async processing/abort etc
      def batch(params)
        responses = params[:requests].each_with_object({}) do |(k, v), h|
          h[k] = new(v[:action], v[:params]).call
        end

        { responses: responses }
      end
    end

    def initialize(action, context)
      @action = ServiceProtocol.constantizer(action)
      @context = context

      raise_if_internal
    end

    def call
      as_json action.call(context)
    end

    def as_json(output = context)
      hash = output.to_h

      # convert ServiceProtocol Context into a json hash based on its attribute config.
      if action.respond_to?(:attributes)
        attributes = action.attributes.select(&:log)
        hash = hash.slice(*attributes.map(&:name) + [:errors])

        attributes.each do |attr|
          if v = output[attr.name]
            hash[attr.name] = v.as_json as_json_options(output, attr)
          end
        end
      end

      hash.as_json
    end

    def as_json_options(output, attr)
      options = attr.options[:as_json]
      options = ->(o) { o.includes && { include: o.includes } } if options == true
      options.is_a?(Proc) ? options.call(output) : options
    end

    def to_json(output = context)
      as_json(output).to_json
    end

    private

    def logger
      instance_variable_memo do
        defined?(LOGGER) ? LOGGER : Logger.new(STDOUT)
      end
    end

    # @todo security: only works on classes that implement allow_remote but should block all.
    def raise_if_internal
      return unless action.respond_to?(:allow_remote) && action.allow_remote

      raise "#{action} does not allow remote access"
    rescue StandardError => e # disabled due to possible Thread issues.
      logger.warn(context.to_h.merge(warn: e.message))
      # raise e
    end

    def return_keys
      return unless action.respond_to?(:attributes)

      action.attributes.select(&:log).map(&:name) + [:errors]
    end
  end
end