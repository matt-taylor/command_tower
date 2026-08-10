# frozen_string_literal: true

module CommandTower
  module Messaging
    module RecipientReadiness
      # Bounded identity facts for readiness. Schema reflection for phone
      # support stays here until Identity ships canonical phone fields.
      IdentityFacts = Data.define(
        :email_supported,
        :email_present,
        :email_validated,
        :phone_supported,
        :phone_present,
        :phone_number_validated,
      ) do
        def self.for_user(user)
          phone_supported = phone_capability_exposed?(user)

          new(
            email_supported: true,
            email_present: user.email.to_s.strip.present?,
            email_validated: !!user.email_validated,
            phone_supported:,
            phone_present: phone_supported && phone_value_present?(user),
            phone_number_validated: phone_supported && !!read_phone_validated(user),
          ).freeze
        end

        def self.phone_capability_exposed?(user)
          return false if user.nil?

          columns = user.class.column_names
          columns.include?("phone_number") && columns.include?("phone_number_validated")
        end
        private_class_method :phone_capability_exposed?

        def self.phone_value_present?(user)
          value = user.public_send(:phone_number)
          value.to_s.strip.present?
        rescue NoMethodError
          false
        end
        private_class_method :phone_value_present?

        def self.read_phone_validated(user)
          user.public_send(:phone_number_validated)
        rescue NoMethodError
          false
        end
        private_class_method :read_phone_validated
      end
    end
  end
end
