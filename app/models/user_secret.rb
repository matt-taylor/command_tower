# frozen_string_literal: true

# == Schema Information
#
# Table name: user_secrets
#
#  id            :bigint           not null, primary key
#  death_time    :datetime
#  extra         :string(255)
#  reason        :string(255)
#  secret        :string(255)
#  secret_digest :string(64)
#  use_count     :integer          default(0)
#  use_count_max :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_user_secrets_on_secret          (secret) UNIQUE
#  index_user_secrets_on_secret_digest   (secret_digest) UNIQUE
#  index_user_secrets_on_user_id         (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class UserSecret < ApplicationRecord
  belongs_to :user

  DIGEST_KEY_PURPOSE = "command_tower.user_secret_digest"

  # Keyed digest of a plaintext secret. Only the digest is persisted.
  def self.digest_for(plaintext)
    OpenSSL::HMAC.hexdigest("SHA256", digest_key, plaintext.to_s)
  end

  def self.digest_key
    @digest_key ||= Rails.application.key_generator.generate_key(DIGEST_KEY_PURPOSE, 32)
  end

  def self.find_record(secret:, reason: nil, user: nil, access_count: true)
    params = { secret_digest: digest_for(secret), reason:, user_id: user&.id }.compact
    record = where(**params).first
    return { found: false } if record.nil?

    record.access_count! if access_count

    {
      found: true,
      valid: record.is_valid?,
      record: record,
      user: record.user,
    }
  end

  def invalid_reason
    arr = []
    arr << "Expired secret." if !still_alive?
    arr << "Secret used too many times." if !valid_use_count?

    arr
  end

  def access_count!
    update(use_count: use_count + 1)
  end

  def is_valid?
    valid_use_count? && still_alive?
  end

  def valid_use_count?
    return true if use_count_max.nil?

    use_count <= use_count_max
  end

  def still_alive?
    return true if death_time.nil?

    death_time > Time.now
  end
end
