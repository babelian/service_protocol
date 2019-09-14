# frozen_string_literal: true

require 'rack'
require 'service_protocol/proxy_action'
require 'logger'

module ServiceProtocol
  # HTTP/JSON server for RPC calls
  class WebServer
    HEALTHY_RESPONSE = [200, { 'Content-Type' => 'text/html' }, ['OK']].freeze

    attr_reader :request

    # Thread safety
    def self.runner
      ->(env) { new.call(env) }
    end

    def call(env)
      @request = Rack::Request.new(env)
      @start = Time.now

      puts log_line

      case path
      when '/health'
        HEALTHY_RESPONSE
      else
        proxy_action
      end
    rescue StandardError => e
      render_error(e)
    ensure
      @input = nil
    end

    # give it some space in logs for debugging.
    prepend_block do
      def call(*args)
        puts "\n\n\n"
        super
      ensure
        puts "\n\n\n"
      end
    end

    private

    def authenticates?
      ENV['SERVICE_PROTOCOL_TOKEN'].split(',').include?(token)
    end

    def environment
      ENVIRONMENT
    rescue NameError
      'development'
    end

    def proxy_action
      if authenticates?
        render 200, ServiceProtocol::ProxyAction.call(action, input[:params], input[:meta])
      else
        render(401, error: 'Authentication Failed')
      end
    end

    #
    # Logging
    #

    def logger
      instance_variable_memo do
        defined?(LOGGER) ? LOGGER : Logger.new(STDOUT)
      end
    end

    def app
      defined?(APP) ? APP : nil
    end

    def log(hash)
      duration = (Time.now - @start) * 1000
      meta = (input[:meta] || {}).dup
      meta.delete(:segement_id)
      logger.info meta.merge(
        source: app,
        data: input[:params].inspect, path: path, duration: duration, remote_ip: remote_ip
      ).merge(hash)
    end

    def puts(*args)
      return if @request && path == '/health'
      return unless environment == 'development'

      super
    end

    #
    # Request Data
    #

    def action
      path[1..-1]
    end

    def log_line
      "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} #{remote_ip} #{path} #{input.inspect}"
    end

    def input
      @input ||= JSON.parse(request.body.read.nil_if_empty || '{}', symbolize_names: true)
    end

    def path
      request.path_info.sub(ENV['SERVICE_PROTOCOL_PATH_PREFIX'].to_s, '')
    end

    def remote_ip
      request.fetch_header('REMOTE_ADDR')
    end

    def token
      request.has_header?('HTTP_X_SERVICE_PROTOCOL_TOKEN') &&
        request.fetch_header('HTTP_X_SERVICE_PROTOCOL_TOKEN')
    end

    #
    # Response
    #

    def render(status, body)
      puts 'BODY: ' + body.inspect unless status == 500

      res = if body.is_a?(String)
              [status, { 'Content-Type' => 'text/html' }, [body]]
            else
              [status, { 'Content-Type' => 'application/json' }, [body.to_json]]
            end

      log body.slice(:errors).merge(status: status.to_s)

      res
    end

    def render_error(error)
      backtrace = error.backtrace.select { |l| l.include?(ENV['PWD']) }.join("\n")
      Kernel.puts 'ServiceProtocol::WebServer Error:'
      Kernel.puts error.inspect
      Kernel.puts backtrace

      render(500, errors: [error.message], error: error.inspect, backtrace: backtrace)
    end
  end
end