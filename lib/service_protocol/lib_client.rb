# frozen_string_literal: true

require 'service_protocol/base_client'

module ServiceProtocol
  # Direct class protocol that bypasses ProxyAction/ValueObject.context serialization
  # RemoteAction.call('action', params) === Action.call(params)
  class LibClient < BaseClient
    def call
      require 'service_protocol/proxy_action'
      ServiceProtocol.constantizer(action).call(params)
    end
  end
end
