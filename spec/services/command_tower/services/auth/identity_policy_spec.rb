# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::IdentityPolicy do
  describe ".call" do
    subject(:result) { described_class.call }

    let(:plain_text) { CommandTower.config.login.plain_text }
    let(:username) { CommandTower.config.username }
    let(:email_verify) { CommandTower.config.login.plain_text.email_verify }

    it "serves the configured inclusive bounds as-is, with the byte limit and iOS password rules" do
      expect(result).to be_success
      expect(result.data[:policy][:password]).to include(
        min_length: plain_text.password_length_min,
        max_length: plain_text.password_length_max,
        max_bytes: 72,
        password_rules: "minlength: #{plain_text.password_length_min}; maxlength: #{plain_text.password_length_max};"
      )
      expect(result.data[:policy][:email]).to include(
        min_length: plain_text.email_length_min,
        max_length: plain_text.email_length_max
      )
    end

    describe "password rules" do
      let(:rules) { result.data[:policy][:password][:rules] }

      it "serves them ordered with their check location" do
        expect(rules.map { |r| [r[:id], r[:check]] }).to eq(
          [%w[min_length client], %w[max_length client], %w[not_common server], %w[not_identifier client]]
        )
        expect(rules).to all(include(:label))
      end
    end

    it "serves email rules" do
      expect(result.data[:policy][:email][:rules].pluck(:id)).to eq(%w[format length])
    end

    it "returns username metadata with a JavaScript-compatible pattern" do
      expect(result.data[:policy][:username]).to include(
        min_length: username.username_length_min,
        max_length: username.username_length_max,
        pattern: "^\\w{#{username.username_length_min},#{username.username_length_max}}$",
        pattern_description: username.username_failure_message
      )
    end

    describe "username rules" do
      let(:rules) { result.data[:policy][:username][:rules] }

      it "serves them with availability checked by the server" do
        expect(rules.map { |r| [r[:id], r[:check]] }).to eq(
          [%w[format client], %w[min_length client], %w[max_length client], %w[available server]]
        )
      end
    end

    it "serves the username host config, defaulting to no self-service" do
      expect(result.data[:policy][:username]).to include(
        self_service: false,
        self_change: false,
        prompt: "after_signup"
      )
    end

    context "with configured username flags" do
      before { allow(username).to receive_messages(self_service: true, self_change: true, prompt: "off") }

      it "reflects them" do
        expect(result.data[:policy][:username]).to include(self_service: true, self_change: true, prompt: "off")
      end
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
