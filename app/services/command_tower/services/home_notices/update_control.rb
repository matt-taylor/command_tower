# frozen_string_literal: true

module CommandTower
  module Services
    module HomeNotices
      # Sets the kill switch of one notice key (design §3.4, doc 03 §6). A key with no control row is
      # enabled, so the row is created on the first change.
      #
      # Inputs: `key` (String), `enabled` (true or false) and `updated_by_user_id` (the admin).
      # Success data is `{ key:, enabled:, previous_enabled:, changed: }`. `changed` is true only when
      # this request changed the effective state: setting a key to the state it already has is an
      # idempotent success with `changed: false`, and the caller audits only a change.
      #
      # The row is locked while it is read and written, so concurrent requests see each other's
      # change. When two requests race to create the first row, the loser retries as an update.
      # A database failure is a failed result (`InternalError`).
      class UpdateControl < CommandTower::Services::ApplicationService
        validate :key, is_a: String, required: true
        validate :enabled, is_a: [TrueClass, FalseClass], required: true
        validate :updated_by_user_id, is_a: [Integer, NilClass], required: false

        def call
          finish(transaction { apply })
        rescue ActiveRecord::ActiveRecordError => e
          context.fail!(application_error: CommandTower::Errors::InternalError.new(cause: e))
        end

        private

        def finish(outcome)
          context.key = key
          context.enabled = enabled
          context.previous_enabled = outcome[:previous_enabled]
          context.changed = outcome[:previous_enabled] != enabled
        end

        def apply
          control = CommandTower::HomeNoticeControl.lock.find_by(key:) || create_control
          previous = control.enabled
          control.update!(enabled:, updated_by_user_id:) if previous != enabled
          { previous_enabled: previous }
        end

        # A new row starts enabled (the absent-row default). A concurrent request may create the
        # row first; this one then locks and updates it.
        def create_control
          CommandTower::HomeNoticeControl.transaction(requires_new: true) do
            CommandTower::HomeNoticeControl.create!(key:, enabled: true)
          end
        rescue ActiveRecord::RecordNotUnique
          CommandTower::HomeNoticeControl.lock.find(key)
        end
      end
    end
  end
end
