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

RSpec.describe User, type: :model do
  describe "username uniqueness" do
    it "allows several users without a username" do
      create(:user, username: nil)

      expect(build(:user, username: nil)).to be_valid
    end

    it "rejects a duplicate username" do
      create(:user, username: "taken_name")

      expect(build(:user, username: "taken_name")).not_to be_valid
    end
  end
end
