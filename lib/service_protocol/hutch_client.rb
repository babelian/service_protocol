require 'service_protocol/base_client'

module ServiceProtocol
  # Hutch/RabbitMQ client for RPC requests
  class HutchClient < BaseClient
    def call
      message_inspect
      setup_reply

      # send request
      exchange.publish(JSON.dump(context), properties)

      # wait for response
      lock.synchronize do
        puts 'locked started'
        condition.wait(lock)
      end
      puts 'lock finished'

      response
    end

    private

    def message_inspect
      puts "To: #{operation}, reply: #{reply_queue.name}, id: #{call_id}"
      puts context.to_json
    end

    #
    # Request
    #

    def channel
      @channel ||= Hutch.broker.channel
    end

    def exchange
      @exchange ||= Hutch.broker.channel.default_exchange
    end

    #
    # Request
    #

    alias routing_key service_name

    def properties
      {
        routing_key: operation, correlation_id: call_id, reply_to: reply_queue.name,
        headers: { action: action }
      }
    end

    #
    # Reply + Mutex Lock
    #

    def lock
      @lock ||= Mutex.new
    end

    def condition
      @condition ||= ConditionVariable.new
    end

    def reply_channel
      @reply_channel ||= Hutch.broker.connection.create_channel
    end

    def reply_queue
      @reply_queue ||= reply_channel.queue('', exclusive: true)
    end

    def setup_reply
      that = self
      reply_queue.subscribe do |_delivery_info, properties, payload|
        puts 'Received reply:'
        puts payload
        if properties[:correlation_id] == that.send(:call_id)
          that.response = payload
          that.send(:reply_channel).close
          that.send(:lock).synchronize { that.send(:condition).signal }
        end
      end
    end
  end
end