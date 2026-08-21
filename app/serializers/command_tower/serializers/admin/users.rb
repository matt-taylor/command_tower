# frozen_string_literal: true

module CommandTower
  module Serializers
    module Admin
      module Users
        class UserSerializer < CommandTower::Serializers::ApplicationSerializer
          def self.serialize(user)
            first_name = user.first_name.to_s
            last_name = user.last_name.to_s
            full_name = [first_name, last_name].map(&:strip).reject(&:empty?).join(" ")
            full_name = user.full_name.strip if full_name.empty? && user.respond_to?(:full_name)

            {
              id: user.id,
              firstName: first_name,
              lastName: last_name,
              fullName: full_name,
              username: user.username,
              email: user.email,
              emailValidated: user.email_validated,
              phoneNumber: phone_number_for(user),
              phoneNumberValidated: phone_number_validated_for(user),
              roles: user.roles,
              createdAt: user.created_at&.iso8601
            }
          end

          def self.phone_number_for(user)
            return nil unless user.respond_to?(:phone_number)

            user.phone_number.presence
          end
          private_class_method :phone_number_for

          def self.phone_number_validated_for(user)
            return false unless user.respond_to?(:phone_number_validated)

            !!user.phone_number_validated
          end
          private_class_method :phone_number_validated_for
        end

        class PaginationMetaSerializer < CommandTower::Serializers::ApplicationSerializer
          def self.serialize(pagination)
            {
              limit: pagination.fetch(:limit),
              offset: pagination.fetch(:offset),
              totalCount: pagination.fetch(:total_count)
            }
          end
        end

        class AssignableRolesSerializer < CommandTower::Serializers::ApplicationSerializer
          def self.serialize(roles)
            {
              roles: Array(roles).map do |role|
                {
                  name: role.fetch(:name),
                  description: role.fetch(:description)
                }
              end
            }
          end
        end
      end
    end
  end
end
