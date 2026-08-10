# frozen_string_literal: true

module CommandTower
  module Serializers
    class ApplicationSerializer
      def self.serialize(*)
        raise NotImplementedError
      end

      def self.map_serialize(collection, serializer = nil, &block)
        items = collection.nil? ? [] : Array(collection)
        if block
          items.map(&block)
        else
          items.map { |item| serializer.serialize(item) }
        end
      end

      def self.iso8601(time)
        return nil if time.nil?

        time.iso8601
      end
    end
  end
end
