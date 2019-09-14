# frozen_string_literal: true

require 'ruby_extensions/module_extensions'

# rubocop:disable all
class Hash
  # https://www.rubydoc.info/github/rubyworks/facets/Hash:traverse
  # Added  Array === v line
  def traverse(&block)
    inject({}) do |h,(k,v)|
      if Hash === v
        v = v.traverse(&block)
      elsif Array === v
        v = v.map { |x| { val: x }.traverse(&block)[:val] }
      elsif v.respond_to?(:to_hash)
        v = v.to_hash.traverse(&block)
      end
      nk, nv = block.call(k,v)
      h[nk] = nv
      h
    end
  end
end

unless Hash.new.respond_to?(:as_json)
  class Hash
    # https://apidock.com/rails/Hash/as_json
    def as_json(_options = nil)
      Hash[self.map { |k, v| [k.to_s, v.respond_to?(:as_json) ? v.as_json : v] }]
    end

    def to_json(options = nil)
      JSON.generate as_json(options)
    end
  end
end
# rubocop:enable all

# ServiceProtocol
module ServiceProtocol
  autoload :BaseClient,     'service_protocol/base_client'
  autoload :Configuration,  'service_protocol/configuration'
  autoload :LibClient,      'service_protocol/lib_client'
  autoload :RedisClient,    'service_protocol/redis_client'
  autoload :RedisServer,    'service_protocol/redis_server'
  autoload :ProxyAction,    'service_protocol/proxy_action'
  autoload :RemoteAction,   'service_protocol/remote_action'
  autoload :ValueObject,    'service_protocol/value_object'
  autoload :WebClient,      'service_protocol/web_client'
  autoload :WebServer,      'service_protocol/web_server'
  autoload :VERSION,        'service_protocol/version'

  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  #
  # ActiveSupport Helpers
  #

  def self.constantizer(word)
    constantize(camelize(word))
  end

  # activesupport/lib/active_support/inflector/methods.rb
  # rubocop:disable all
  def self.camelize(string, uppercase_first_letter = true)
    if uppercase_first_letter
      string = string.sub(/^[a-z\d]*/) { $&.capitalize }
    else
      string = string.sub(/^(?:(?=\b|[A-Z_])|\w)/) { $&.downcase }
    end
    string.gsub(/(?:_|(\/))([a-z\d]*)/) { "#{$1}#{$2.capitalize}" }.gsub('/', '::')
  end

  def self.constantize(camel_cased_word)
    names = camel_cased_word.split("::")

    # Trigger a built-in NameError exception including the ill-formed constant in the message.
    Object.const_get(camel_cased_word) if names.empty?

    # Remove the first blank element in case of '::ClassName' notation.
    names.shift if names.size > 1 && names.first.empty?

    names.inject(Object) do |constant, name|
      if constant == Object
        constant.const_get(name)
      else
        candidate = constant.const_get(name)
        next candidate if constant.const_defined?(name, false)
        next candidate unless Object.const_defined?(name)

        # Go down the ancestors to check if it is owned directly. The check
        # stops when we reach Object or the end of ancestors tree.
        constant = constant.ancestors.inject(constant) do |const, ancestor|
          break const    if ancestor == Object
          break ancestor if ancestor.const_defined?(name, false)
          const
        end

        # owner is in Object, so raise
        constant.const_get(name, false)
      end
    end
  end
  # rubocop:enable all
end

ServiceProtocol.configure {}