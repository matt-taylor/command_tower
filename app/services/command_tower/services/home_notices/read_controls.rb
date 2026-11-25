# frozen_string_literal: true

module CommandTower
  module Services
    module HomeNotices
      # Reads the kill switch for a set of notice keys (design §3.4, doc 03 §6). An absent control
      # row means enabled, so only keys with a row set to `enabled: false` are returned.
      #
      # Success data is `{ disabled_keys: Set<String> }`. A database failure is a failed result
      # (`InternalError`); callers fail closed and show no notices.
      class ReadControls < CommandTower::Services::ApplicationService
        validate :keys, is_a: Array, required: true

        def call
          context.disabled_keys = disabled_keys
        rescue ActiveRecord::ActiveRecordError => e
          context.fail!(application_error: CommandTower::Errors::InternalError.new(cause: e))
        end

        private

        def disabled_keys
          names = keys.map(&:to_s).uniq
          return Set.new if names.empty?

          CommandTower::HomeNoticeControl.where(key: names, enabled: false).pluck(:key).to_set
        end
      end
    end
  end
end
