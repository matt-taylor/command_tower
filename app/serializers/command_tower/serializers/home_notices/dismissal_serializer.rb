# frozen_string_literal: true

module CommandTower
  module Serializers
    module HomeNotices
      # The payload of a dismiss: `{ id, dismissedUntil }` (design §3.3). `id` follows
      # `NoticeSerializer`: `campaign:<key>` for a campaign, the row `public_id` for a delivery.
      class DismissalSerializer
        def self.serialize(notice_class:, public_id:, dismissed_until:)
          campaign = notice_class < CommandTower::HomeNotices::Campaign
          {
            id: campaign ? "campaign:#{notice_class.key}" : public_id,
            dismissedUntil: dismissed_until&.utc&.iso8601
          }
        end
      end
    end
  end
end
