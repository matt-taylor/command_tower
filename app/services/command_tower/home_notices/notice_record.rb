# frozen_string_literal: true

module CommandTower
  module HomeNotices
    # Read-only snapshot of a persisted `HomeNotice` row, handed to `show?` and `compose` so host
    # code cannot mutate platform state.
    NoticeRecord = Data.define(
      :public_id, :kind, :key, :campaign_key, :period_key, :identity, :communication_id,
      :starts_at, :ends_at, :metadata, :impression_count, :first_shown_at, :last_shown_at,
      :acknowledged_at, :dismissed_until
    ) do
      # @param record [CommandTower::HomeNotice]
      def self.from(record)
        new(**members.index_with { |member| record.public_send(member) }).then do |snapshot|
          snapshot.with(metadata: deep_freeze(snapshot.metadata))
        end
      end

      def self.deep_freeze(value)
        case value
        when Hash then value.each_value { |v| deep_freeze(v) }
        when Array then value.each { |v| deep_freeze(v) }
        end
        value.freeze
      end
    end
  end
end
