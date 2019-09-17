# frozen_string_literal: true

require 'service_protocol/entity'

module ServiceProtocol
  module Spec
    module Support
      # Remote Helpers
      module RemoteHelpers
        # @see {#allow_remote} or {#expect_remote}
        # @param [String] approach either 'allow'  or 'expect'
        def allow_or_expect_remote(approach, operation = nil, input = any_args, output = nil)
          method = send(approach, ServiceProtocol::Remote).to receive(:call)
          method = if operation
                     method.with operation, input
                   else
                     method.and_call_original
                   end

          method = method.and_return(ServiceProtocol::Entity.context(output)) if output
          method
        end

        def allow_remote(*args)
          args.unshift :allow
          allow_or_expect_remote(*args)
        end

        def expect_remote(*args)
          args.unshift :expect
          allow_or_expect_remote(*args)
        end

        def expect_remote_to_have_received(*args)
          expect(ServiceProtocol::Remote).to have_received(:call).with(*args)
        end
      end
    end
  end
end
