require 'hutch'
module ServiceProtocol
  # HutchServer

  # Boot example
  # hutch --require service_boot.rb
  # service_boot.rb:
  <<~RUBY
    require 'hutch'
    Hutch::Config.enable_http_api_use = false

    begin
      # allow time for local docker rabbitmq to come online
      Hutch.connect
    rescue Hutch::ConnectionError => e
      @count ||= 0
      raise e if @count > 20

      @count += 1
      puts "Waiting for Rabbit MQ: #{@count}"
      sleep(1)
      retry
    end

    # Start a Hutch Consumer server
    if $PROGRAM_NAME.match?(%r{bin/hutch$})
      # Hutch::Config.set(:tracer, Hutch::Tracers::NewRelic)

      # TODO: remove hard coded logic
      project_root = '/app' # hard coded docker app location
      files = Dir.glob(project_root + '/app/consumers/*.rb')
      files.each { |f| require f }

      puts 'Hutch loaded'
    end
  RUBY

  module HutchServer
    extend ActiveSupport::Concern
    included do
      include Hutch::Consumer
    end

    attr_reader :message, :context
    delegate :properties, to: :message

    def process(message)
      @message = message
      message_inspect
      @context = ServiceProtocol::ProxyAction.call(action, input)
      reply
    end

    private

    def action
      properties.headers[:action]
    end

    def input
      message.body
    end

    def message_inspect
      puts "#{self.class.name} #{message.routing_key}"
      puts message.body.inspect
      puts message.properties.inspect
    end

    def reply_properties
      return unless properties.reply_to
      { routing_key: properties.reply_to, correlation_id: properties.correlation_id }
    end

    def response
      instance_variable_memo { context.to_h.to_json }
    end

    # RPC reply to the Producer if they specified a reply_to routing_key
    def reply
      return unless reply_properties
      puts 'Replying:'
      puts reply_properties.inspect
      puts response

      # Hutch.broker.channel.queue(reply_properties[:routing_key]).publish(response, reply_properties)
      Hutch.broker.channel.default_exchange.publish(response, reply_properties)
      puts 'replied'
    end
  end
end