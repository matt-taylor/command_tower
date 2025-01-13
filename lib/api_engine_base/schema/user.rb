# frozen_string_literal: true

module ApiEngineBase
  module Schema
    class User < JsonSchematize::Generator
      schema_default option: :dig_type, value: :string

      def self.convert_user_object(user:)
        attributes = ApiEngineBase.config.user.default_attributes.map(&:to_s)
        object = user.attributes.slice(*attributes)

        new(object)
      end

      # Gets assigned during configuration phase via
      # lib/api_engine_base/configuration/user/config.rb
      def self.assign!
        attributes = ApiEngineBase.config.user.default_attributes
        attributes.each do |attribute|
          if metadata = ::User.attribute_to_type_mapping[attribute]
            type = metadata[:serialized_type] ? metadata[:serialized_type] : metadata[:base]
            add_field(name: attribute, type:)
          end
        end
      end
    end
  end
end
