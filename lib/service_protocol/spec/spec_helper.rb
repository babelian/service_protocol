# frozen_string_literal: true

require 'service_protocol/spec/support/remote_helpers'

RSpec.configure do |config|
  config.include Matchers
  config.include ServiceProtocol::Spec::Support::RemoteHelpers # , type: [:operation, :request]
end