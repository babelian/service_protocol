# frozen_string_literal: true

require 'ostruct'

module ServiceProtocol
  # Generate  Struct-based value objects for {RemoteAction} to rehydrate with.
  class ValueObject < Struct
    OBJECT_KEYS = [:attributes, :id, :type].freeze

    class << self
      def classes
        @classes ||= {}
      end

      def context(hash = {})
        # ensure Hash with symbolized keys
        hash = JSON.generate(hash) if hash.is_a?(Hash) && hash.keys.first.is_a?(String)
        hash = JSON.parse(hash, symbolize_names: true) if hash.is_a?(String)

        # reconsitute typed Objects, has to handle string and symbol keys for BaseClient
        hash = hash.traverse do |k, v|
          if v.is_a?(Hash) && (v.keys & OBJECT_KEYS).sort == OBJECT_KEYS
            # v = build(v[:type], v[:attributes].merge(id: v[:id]))
            v = OpenStruct.new v[:attributes].merge(id: v[:id], _type: v[:type])
          end
          [k.to_sym, v]
        end

        hash[:failure?] = hash[:errors] && !hash[:errors].empty?
        hash[:success?] = !hash[:failure?]

        OpenStruct.new hash
      end

      # Convert a hash into a value object
      #
      # @param name [Symbol, String] eg 'Resource' or :resource
      # @param attributes [Hash]
      #
      # @return value object
      def build(name, attributes)
        klass = class_for(name, attributes.keys + [:_type])
        keys = klass.new.to_h.keys
        klass.new(attributes.slice(*keys).merge(_type: name))
      end

      # Convert array of hashes into value objects
      #
      # @param name [Symbol, String] eg 'Resource' or :resource
      # @param array [Array<Hash>] of hash data
      # @yieldparam [optional, object] during loop
      #
      # @return [Array<value object>]
      def build_all(name, array)
        return [] unless array.first

        klass = class_for(name, array.first.keys)
        keys = klass.new.to_h.keys

        array.map do |h|
          obj = klass.new(h.slice(*keys))
          yield(obj) if block_given?
          obj
        end
      end

      def build_all_hashed_on_id(name, array, &block)
        ValueObject.build_all(name, array, &block).each_with_object({}) do |obj, hash|
          hash[obj.id] = obj
        end
      end

      # Create a Struct-based class for the given name/data combo
      # @param name [Symbol, String] eg 'Resource' or :resource
      # @param attribute_names [Hash] example data structure
      # @return defined value object class
      def class_for(name, attribute_names)
        name = ServiceProtocol.camelize(name.to_s)
        classes[[name, attribute_names]] ||= begin
          keys = attribute_names
          # mix in :relation for :relation_id
          keys += attribute_names.grep(/_id$/).map { |k| k[/(.*)_id/, 1].to_sym }

          struct = new(*keys.uniq, keyword_init: true)

          Object.const_set(name, struct)
        end
      end

      private
    end

    def as_json(options = {})
      { 'id' => id, 'type' => self.class.name, 'attributes' => super(options).except('id') }
    end
  end
end