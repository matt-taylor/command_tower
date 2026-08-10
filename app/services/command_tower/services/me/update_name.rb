# frozen_string_literal: true

module CommandTower
  module Services
    module Me
      class UpdateName < CommandTower::Services::ApplicationService
        validate :user, is_a: User, required: true
        validate :first_name, is_a: String, required: true
        validate :last_name, is_a: String, required: true

        def call
          normalized_first = first_name.to_s.strip
          normalized_last = last_name.to_s.strip

          first_changed = normalized_first != user.first_name.to_s
          last_changed = normalized_last != user.last_name.to_s

          unless first_changed || last_changed
            context.user = user
            return
          end

          application_error = nil

          ActiveRecord::Base.transaction do
            if first_changed
              application_error = mutate(first_name: normalized_first)
              raise ActiveRecord::Rollback if application_error
            end

            if last_changed
              application_error = mutate(last_name: normalized_last)
              raise ActiveRecord::Rollback if application_error
            end
          end

          if application_error
            context.fail!(application_error:)
            return
          end

          context.user = user.reload
        end

        private

        # Returns an ApplicationError when the change was rejected, nil otherwise.
        def mutate(**attribute)
          result = CommandTower::UserAttributes::Mutate.call(user:, **attribute)
          return nil if result.success?

          details = result.invalid_argument_hash.transform_values { _1[:msg].to_s }
          CommandTower::Errors::ValidationError.new(details:)
        end
      end
    end
  end
end
