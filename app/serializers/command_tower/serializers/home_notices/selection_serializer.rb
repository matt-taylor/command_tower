# frozen_string_literal: true

module CommandTower
  module Serializers
    module HomeNotices
      # The `GET /me/home-notices` payload: `{ blocking, dismissible, readOnly }` (design §3.3).
      class SelectionSerializer
        # @param blocking [PickNotices::Pick, nil]
        # @param dismissible [PickNotices::Pick, nil]
        # @param read_only [Boolean] true while impersonating (or when that is unknown)
        def self.serialize(blocking:, dismissible:, read_only:)
          {
            blocking: blocking && NoticeSerializer.serialize(blocking),
            dismissible: dismissible && NoticeSerializer.serialize(dismissible),
            readOnly: read_only
          }
        end
      end
    end
  end
end
