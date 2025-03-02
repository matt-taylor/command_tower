# frozen_string_literal: true

module CommandTower
  module Schema
    class User < JsonSchematize::Generator
      schema_default option: :dig_type, value: :string

      def self.convert_user_object(user:)
        attributes = CommandTower.config.user.default_attributes.map(&:to_s)
        object = user.attributes.slice(*attributes)

        new(object)
      end

      # Gets assigned during configuration phase via
      # lib/command_tower/configuration/user/config.rb
      def self.assign!
        attributes = CommandTower.config.user.default_attributes
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
