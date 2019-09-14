# frozen_string_literal: true

require 'service_protocol/value_object'

module ServiceProtocol
  module Spec
    module Support
      # Remote Helpers
      module RemoteHelpers
        # @see {#allow_remote_action} or {#expect_remote_action}
        # @param [String] approach either 'allow'  or 'expect'
        def allow_or_expect_remote_action(approach, operation = nil, input = any_args, output = nil)
          method = send(approach, ServiceProtocol::RemoteAction).to receive(:call)
          method = if operation
                     method.with operation, input
                   else
                     method.and_call_original
                   end

          method = method.and_return(ServiceProtocol::ValueObject.context(output)) if output
          method
        end

        def allow_remote_action(*args)
          args.unshift :allow
          allow_or_expect_remote_action(*args)
        end

        def expect_remote_action(*args)
          args.unshift :expect
          allow_or_expect_remote_action(*args)
        end

        def expect_remote_action_to_have_received(*args)
          expect(ServiceProtocol::RemoteAction).to have_received(:call).with(*args)
        end

        def stub_get_url(url, body)
          instance_variable_memo do
            require 'faraday'
            faraday_stub = Faraday.new do |builder|
              builder.adapter :test do |stub|
                stub.get(url) { |_env| [200, {}, body] }
              end
            end
            allow(Faraday).to receive(:new).and_return(faraday_stub)
          end
          # allow(Faraday).to receive(:get).with(url).and_return(OpenStruct.new(body: body))
        end

        # Used in specs/api/*.yaml remote:
        def stub_service!(operation, input, context = nil)
          input = input
          expect = expect_remote_action operation, stubbed_input(input)
          if context
            expect.and_return ServiceProtocol::ValueObject.context(context.deep_symbolize_keys)
          else
            expect
          end
        end

        def stubbed_input(input)
          input.reformat do |k, v|
            [k, v.is_a?(Symbol) ? eval(v.to_s) : v] # rubocop:disable Security/Eval
          end
        end
      end
    end
  end
end