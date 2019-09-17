# frozen_string_literal: true

require 'service_protocol/base_client'
require 'net/http'
require 'uri'

module ServiceProtocol
  # Web based HTTP/JSON client for RPC requests
  class WebClient < BaseClient
    # Anything other than status `200` raises this.
    class ResponseError < StandardError
      attr_reader :response

      # @param [Net::HTTPResponse]
      def initialize(response)
        @response = response
        super
      end

      # @return [String]
      def body
        JSON.parse(response.body).to_yaml
      rescue JSON::ParserError
        response.body
      end

      # @return [String]
      def message
        "#{response.env.url} failed: #{response.status}\n#{body}"
      end
    end

    def call
      JSON.parse(response.body, symbolize_names: true)
    rescue JSON::ParserError
      { status: response.status, body: response.body[0..100] }
    end

    private

    alias host service_name
    alias path operation

    def headers
      {
        'Content-Type' => 'application/json',
        'X-SERVICE-PROTOCOL-TOKEN' => token
      }
    end

    def host_url
      url = ENV["#{host.upcase}_URL"] || "http://#{host}"
    end

    def path_with_prefix
      [ENV['SERVICE_PROTOCOL_PATH_PREFIX'], path].compact.join('/')
    end

    def uri
      @uri ||= URI "#{host_url}/#{path_with_prefix}"
    end

    def http
      http = Net::HTTP.new(uri.host, uri.port)

      return http unless host_url.include?('https')

      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http
    end

    def request
      request = Net::HTTP::Post.new(uri.request_uri, headers)
      request.body = { params: params, meta: meta }.to_json
      request
    end

    def response
      http.request(request)
    end

    # Faraday

    # def connection
    #   require 'faraday'
    #   @connection ||= Faraday.new(host_url, headers: headers)
    # end

    # def response
    #   @response ||= begin
    #     response = http.post do |req|
    #       req.path = path_with_prefix
    #       req.headers['Content-Type'] = 'application/json'
    #       req.body = { params: params, meta: meta }.to_json
    #     end

    #     raise(ResponseError, response) unless response.status.to_s == '200'

    #     response
    #   end
    # end
  end
end
