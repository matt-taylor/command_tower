# frozen_string_literal: true

# == Schema Information
#
# Table name: messages
#
#  id               :bigint           not null, primary key
#  pushed           :boolean          default(FALSE)
#  text             :text(65535)
#  title            :string(255)
#  viewed           :boolean          default(FALSE)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  message_blast_id :bigint
#  user_id          :bigint           not null
#
# Indexes
#
#  index_messages_on_message_blast_id  (message_blast_id)
#  index_messages_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (message_blast_id => message_blasts.id)
#  fk_rails_...  (user_id => users.id)
#
class Message < ApplicationRecord
  belongs_to :user
  belongs_to :message_blast, optional: true
end
