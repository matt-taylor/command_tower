# frozen_string_literal: true

module CommandTower
  # Persistence only. One row per user per notice occurrence (campaign period or delivery identity).
  class HomeNotice < CommandTower::ApplicationRecord
    PERIOD_KEY_LIMIT = 191
    DIGEST_LENGTH = 16

    self.table_name = "command_tower_home_notices"

    belongs_to :user

    before_validation :assign_public_id, on: :create
    before_validation :normalize_period_key

    validates :public_id, presence: true
    validates :kind, :key, presence: true
    validates :period_key, uniqueness: { scope: %i[user_id campaign_key] }, if: -> { campaign_key.present? }
    validates :identity, uniqueness: { scope: :user_id }, if: -> { identity.present? }

    # The stored form of a period key: to_s; an over-long value is truncated and given a digest
    # suffix so it stays unique. Lookups by period key use the same form.
    def self.stored_period_key(value)
      value = value.to_s
      return value if value.length <= PERIOD_KEY_LIMIT

      digest = Digest::SHA256.hexdigest(value).first(DIGEST_LENGTH)
      "#{value.first(PERIOD_KEY_LIMIT - DIGEST_LENGTH - 1)}-#{digest}"
    end

    private

    def assign_public_id
      self.public_id = SecureRandom.alphanumeric(32) if public_id.blank?
    end

    def normalize_period_key
      self.period_key = self.class.stored_period_key(period_key)
    end
  end
end
