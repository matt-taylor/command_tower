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
#  roles                      :string(255)      default([])
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

class User < CommandTower::ApplicationRecord
  has_secure_password

  TOMBSTONE_EMAIL_DOMAIN = "@invalid.local"
  TOMBSTONE_EMAIL_PREFIX = "deleted+"
  TOMBSTONE_USERNAME_PREFIX = "deleted_"

  scope :not_deleted, -> { where(deleted_at: nil) }

  validates :username, uniqueness: { conditions: -> { not_deleted } }
  validates :email, uniqueness: { conditions: -> { not_deleted } }

  ###
  # Serialize the roles column to check for inclusion easily
  serialize :roles, coder: JSON, type: Array

  has_many :messaging_communications,
           class_name: "CommandTower::Messaging::Communication",
           inverse_of: :user,
           foreign_key: :user_id

  def full_name
    "#{first_name} #{last_name}"
  end

  def deleted?
    deleted_at.present?
  end

  def self.tombstone_email_for(id)
    "#{TOMBSTONE_EMAIL_PREFIX}#{id}#{TOMBSTONE_EMAIL_DOMAIN}"
  end

  def self.tombstone_username_for(id)
    "#{TOMBSTONE_USERNAME_PREFIX}#{id}"
  end

  def reset_verifier_token!
    value = SecureRandom.alphanumeric(32)
    update!(verifier_token: value, verifier_token_last_reset: Time.now)

    value
  end

  def retreive_verifier_token!
    return verifier_token if verifier_token

    reset_verifier_token!
  end
end
