# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::PasswordPolicy::Check, :aggregate_failures do
  subject(:result) { described_class.call(password:) }

  let(:plain_text) { CommandTower.config.login.plain_text }
  let(:valid) { result.data[:valid] }
  let(:failures) { result.data[:failures] }
  let(:filler) { "Zq9!" }

  context "with a strong password" do
    let(:password) { "correct-horse-9f3Qz!battery" }

    it "is valid" do
      expect(result).to be_success
      expect(valid).to be(true)
      expect(failures).to eq([])
    end
  end

  context "when exactly at the minimum length" do
    let(:password) { filler * (plain_text.password_length_min / 4) }

    it "is valid (bounds are inclusive)" do
      expect(password.length).to eq(plain_text.password_length_min)
      expect(valid).to be(true)
    end
  end

  context "when exactly at the maximum length" do
    let(:password) { filler * (plain_text.password_length_max / 4) }

    it "is valid (bounds are inclusive)" do
      expect(password.length).to eq(plain_text.password_length_max)
      expect(valid).to be(true)
    end
  end

  context "when one under the minimum" do
    let(:password) { (filler * 2).chop }

    it "reports too_short" do
      expect(password.length).to eq(plain_text.password_length_min - 1)
      expect(valid).to be(false)
      expect(failures).to eq([:too_short])
    end
  end

  context "when one over the maximum" do
    let(:password) { "#{filler * (plain_text.password_length_max / 4)}x" }

    it "reports too_long" do
      expect(valid).to be(false)
      expect(failures).to eq([:too_long])
    end
  end

  context "with a common password" do
    let(:password) { "Password" }

    it "reports blocklisted" do
      expect(valid).to be(false)
      expect(failures).to eq([:blocklisted])
    end
  end

  context "with a short common password" do
    let(:password) { "123456" }

    it "reports every failure" do
      expect(failures).to eq(%i[too_short blocklisted])
    end
  end
end
