# frozen_string_literal: true

# == Schema Information
#
# Table name: message_blasts
#
#  id             :bigint           not null, primary key
#  existing_users :boolean          default(FALSE)
#  new_users      :boolean          default(FALSE)
#  text           :text(65535)
#  title          :string(255)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_message_blasts_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class MessageBlast < ApplicationRecord
  has_many :messages
  belongs_to :user
end
