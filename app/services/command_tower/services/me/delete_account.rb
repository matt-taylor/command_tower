# frozen_string_literal: true

module CommandTower
  module Services
    module Me
      class DeleteAccount < CommandTower::Services::ApplicationService
        FIELD_KEYS = {
          password: :password
        }.freeze

        validate :user, is_a: User, required: true
        validate :password, is_a: String, required: true, sensitive: true

        def call
          if user.deleted?
            context.fail!(
              application_error: CommandTower::Errors::Auth::AccountDeletedError.new
            )
            return
          end

          reject!(password: "Incorrect password") unless user.authenticate(password)

          infrastructure_failure = false

          ActiveRecord::Base.transaction do
            unless invoke_host_finalizer!
              infrastructure_failure = true
              raise ActiveRecord::Rollback
            end

            purge_result = CommandTower::Services::Auth::PurgeUserAssociatedData.call(user:)
            unless purge_result.success?
              infrastructure_failure = true
              raise ActiveRecord::Rollback
            end

            tombstone_result = CommandTower::Services::Auth::TombstoneUser.call(user:)
            unless tombstone_result.success?
              infrastructure_failure = true
              raise ActiveRecord::Rollback
            end

            user.reload
            audit(
              :account_deleted,
              subject: user,
              affected_user: user,
              changes: {},
              metadata: { mechanism: "self_service" }
            )
          end

          if infrastructure_failure
            context.fail!(application_error: CommandTower::Errors::InternalError.new)
            return
          end

          user.reload
          unless user.deleted?
            log_error("Account deletion transaction did not persist for user [#{user.id}]")
            context.fail!(application_error: CommandTower::Errors::InternalError.new)
          end

          log_info("Account deleted for user [#{user.id}]")
          context.message = "Your account has been deleted"
        end

        private

        def invoke_host_finalizer!
          finalizer = CommandTower.config.account_deletion.host_finalizer
          return true if finalizer.nil?

          outcome = finalizer.call(user:)
          return true if outcome.nil?
          return true if outcome.respond_to?(:success?) && outcome.success?

          false
        end

        def reject!(errors)
          details = errors.each_with_object({}) do |(key, message), mapped|
            mapped[FIELD_KEYS.fetch(key.to_sym, key)] = message
          end

          context.fail!(application_error: CommandTower::Errors::ValidationError.new(details:))
        end
      end
    end
  end
end
