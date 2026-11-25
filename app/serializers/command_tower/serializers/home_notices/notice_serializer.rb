# frozen_string_literal: true

module CommandTower
  module Serializers
    module HomeNotices
      # One picked notice: `{ id, key, severity, endsAt, document }` (design §3.3).
      # `id` is `campaign:<key>` for a campaign and the row `public_id` for a delivery.
      class NoticeSerializer
        # @param pick [CommandTower::Services::HomeNotices::PickNotices::Pick]
        def self.serialize(pick)
          klass = pick.notice_class
          {
            id: id_for(klass, pick.record),
            key: klass.key.to_s,
            severity: klass.blocking? ? "blocking" : "dismissible",
            endsAt: ends_at_for(klass, pick.record)&.iso8601,
            document: pick.document.as_json
          }
        end

        def self.id_for(klass, record)
          return "campaign:#{klass.key}" if klass < CommandTower::HomeNotices::Campaign

          record.public_id
        end

        def self.ends_at_for(klass, record)
          record&.ends_at || klass.window&.ends_at
        end

        private_class_method :id_for, :ends_at_for
      end
    end
  end
end
