# frozen_string_literal: true

require 'service_protocol/base_client'

module ServiceProtocol
  # Direct class protocol that bypasses Proxy/Entity.context serialization
  # Remote.call('service_name:operation', params) === Operation.call(params)
  class LibClient < BaseClient
    def call
      require 'service_protocol/proxy'
      ServiceProtocol.constantizer(operation).call(params)
    end
  end
end
