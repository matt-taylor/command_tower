# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                         :bigint           not null, primary key
#  email                      :string(255)      default(""), not null
#  email_validated            :boolean          default(FALSE)
#  first_name                 :string(255)      default(""), not null
#  last_known_timezone        :string(255)
#  last_known_timezone_update :datetime
#  last_login                 :datetime
#  last_login_strategy        :string(255)
#  last_name                  :string(255)      default(""), not null
#  password_consecutive_fail  :integer          default(0)
#  password_digest            :string(255)      default(""), not null
#  recovery_password_digest   :string(255)      default(""), not null
#  successful_login           :integer          default(0)
#  username                   :string(255)
#  verifier_token             :string(255)
#  verifier_token_last_reset  :datetime
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#
# Indexes
#
#  index_users_on_username  (username) UNIQUE
#
require "securerandom"

class User < ApiEngineBase::ApplicationRecord
  has_secure_password

  validates :username, uniqueness: true
  validates :email, uniqueness: true

  def full_name
    "#{first_name} #{last_name}"
  end

  def retreive_verifier_token!
    return verifier_token if verifier_token

    value = SecureRandom.alphanumeric(32)
    update!(verifier_token: value)

    value
  end
end
