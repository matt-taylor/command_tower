# frozen_string_literal: true

module CommandTower
  module Serializers
    module Me
      class PushSerializer
        def self.serialize(safe_view)
          new(safe_view).serialize
        end

        def self.serialize_collection(safe_views)
          {
            endpoints: Array(safe_views).map { |view| serialize(view) },
          }
        end

        def initialize(safe_view)
          @safe_view = safe_view
        end

        def serialize
          {
            id: @safe_view.id,
            channelKey: @safe_view.channel_key,
            lifecycleState: @safe_view.lifecycle_state,
            verificationState: @safe_view.verification_state,
            maskedDisplayValue: @safe_view.masked_display_value,
            verifiedAt: @safe_view.verified_at&.iso8601,
            createdAt: @safe_view.created_at&.iso8601,
            updatedAt: @safe_view.updated_at&.iso8601,
            actions: actions_for(@safe_view),
          }
        end

        private

        def actions_for(view)
          active = view.lifecycle_state.to_s == "active"
          {
            canReplace: active,
            canRemove: active,
          }
        end
      end
    end
  end
end
