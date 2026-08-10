# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::IdentityPolicy do
  describe ".call" do
    subject(:result) { described_class.call }

    let(:plain_text) { CommandTower.config.login.plain_text }
    let(:username) { CommandTower.config.username }
    let(:email_verify) { CommandTower.config.login.plain_text.email_verify }

    it "translates the configured inclusive bounds into exclusive client bounds" do
      expect(result).to be_success
      expect(result.data[:policy][:password]).to eq(
        min_length: plain_text.password_length_min + 1,
        max_length: plain_text.password_length_max - 1
      )
      expect(result.data[:policy][:email]).to eq(
        min_length: plain_text.email_length_min + 1,
        max_length: plain_text.email_length_max - 1
      )
    end

    it "returns username metadata with a JavaScript-compatible pattern" do
      expect(result.data[:policy][:username]).to include(
        min_length: username.username_length_min,
        max_length: username.username_length_max,
        pattern: "^\\w{#{username.username_length_min},#{username.username_length_max}}$",
        pattern_description: username.username_failure_message
      )
    end

    it "returns numeric verification code metadata" do
      expect(result.data[:policy][:verification_code]).to eq(
        length: email_verify.verify_code_length,
        character_set: "numeric"
      )
      expect(result.data[:policy][:phone_verification_code]).to eq(
        length: CommandTower.config.identity.phone_verification.verify_code_length,
        character_set: "numeric"
      )
    end
  end
end
