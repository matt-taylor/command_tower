# frozen_string_literal: true

# Register, reset and change-password must enforce the same password policy with the same message.
RSpec.describe CommandTower::Services::Auth::PasswordPolicy::Check, ".message_for wiring parity", :aggregate_failures do
  let!(:user) { create(:user, email: "parity-user@example.com", password: "correct-horse-9f3Qz!battery") }

  let(:results) do
    plain_text = CommandTower.config.login.plain_text
    token = CommandTower::Secrets::Generate.call(
      user: user,
      secret_length: plain_text.password_reset.token_length,
      reason: CommandTower::Secrets::PASSWORD_RESET,
      use_count_max: 1,
      death_time: plain_text.password_reset.token_valid_for,
      type: CommandTower::Secrets::ALPHANUMERIC,
      cleanse: true
    ).secret

    [
      CommandTower::Services::Auth::Register.call(
        first_name: "Pat", last_name: "Parity", username: "parity#{SecureRandom.hex(4)}",
        email: "parity-#{SecureRandom.hex(4)}@example.com",
        password:, password_confirmation: password
      ),
      CommandTower::Services::Auth::PasswordReset::Reset.call(
        token:, password:, password_confirmation: password
      ),
      CommandTower::Services::Me::ChangePassword.call(
        user:, current_password: "correct-horse-9f3Qz!battery", password:, password_confirmation: password
      )
    ]
  end

  shared_examples "an identically rejected password" do
    it "fails all three entry points with one message" do
      expect(results).to all(be_failure)
      expect(results.map { |result| result.errors.first.details[:password] }.uniq.size).to eq(1)
    end
  end

  context "with a too short password" do
    let(:password) { "a" * (CommandTower.config.login.plain_text.password_length_min - 1) }

    it_behaves_like "an identically rejected password"
  end

  context "with a too long password" do
    let(:password) { "a" * (CommandTower.config.login.plain_text.password_length_max + 1) }

    it_behaves_like "an identically rejected password"
  end

  context "with a blocklisted password" do
    let(:password) { "password1234" }

    it_behaves_like "an identically rejected password"
  end

  describe "inclusive bounds" do
    %i[password_length_min password_length_max].each do |bound|
      context "with a password of exactly #{bound}" do
        let(:length) { CommandTower.config.login.plain_text.public_send(bound) }
        let(:password) { ("Zq9!" * (length / 4)) + ("x" * (length % 4)) }

        it "accepts it" do
          expect(described_class.call(password:).data[:valid]).to be(true)
        end
      end
    end
  end

  describe "email rules" do
    let(:max_email) { "#{'a' * (CommandTower.config.login.plain_text.email_length_max - 5)}@x.co" }

    it "normalizes email to stripped lowercase on the model" do
      expect(User.new(email: "  Mixed.Case@Example.COM ").email).to eq("mixed.case@example.com")
    end

    it "rejects an invalid email format on the model" do
      expect(build(:user, email: "not-an-email")).not_to be_valid
    end

    it "rejects an over-long email on the model" do
      expect(build(:user, email: "#{max_email}m")).not_to be_valid
    end

    it "accepts the inclusive maximum email length" do
      expect(build(:user, email: max_email)).to be_valid
      expect(max_email.length).to eq(CommandTower.config.login.plain_text.email_length_max)
    end
  end
end
