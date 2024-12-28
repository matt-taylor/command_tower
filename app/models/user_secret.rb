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
#  use_count     :integer          default(0)
#  use_count_max :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_user_secrets_on_secret   (secret) UNIQUE
#  index_user_secrets_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class UserSecret < ApplicationRecord
  belongs_to :user

  def self.find_record(secret:, reason: nil, access_count: true)
    params = { secret:, reason: }.compact
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
