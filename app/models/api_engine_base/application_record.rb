# frozen_string_literal: true

module ApiEngineBase
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true

    def self.attribute_to_type_mapping
      @attribute_to_type_mapping ||= begin
        mapping = ActiveSupport::HashWithIndifferentAccess.new
        columns_hash.each do |attribute_name, metadata|
          base = nil
          ruby_type = nil
          allowed_types = nil
          serialized_type = nil
          case metadata.type
          when :string, :text
            base = ruby_type = String
          when :integer, :bigint
            base = ruby_type = Integer
          when :datetime, :time, :date
            base = String
            ruby_type = [DateTime, Time]
          when :float, :decimal
            base = ruby_type = Float
          when :boolean
            base = "Boolean"
            ruby_type = [TrueClass, FalseClass]
            allowed_types = [true, false]
          else
            # All else fails convert to String and continue
            base = ruby_type = String
          end

          attribute_type = attribute_types[attribute_name]
          if attribute_type.is_a?(ActiveRecord::Type::Serialized)
            serialized_type = attribute_type.coder.object_class
          end
          mapping[attribute_name] = { serialized_type:, base:, ruby_type:, allowed_types: }.compact
        end

        mapping
      end
    end
  end
end
