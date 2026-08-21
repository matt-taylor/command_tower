# frozen_string_literal: true

RSpec.describe CommandTower::Services::Admin::Users::UpdateEmail do
  describe ".call" do
    subject(:result) { described_class.call(user:, email:) }

    let(:user) { create(:user, email: "old@example.com", email_validated: true) }
    let(:email) { "new@example.com" }

    it { expect(result).to be_success }

    it "changes the email and clears validation" do
      expect(result.data[:changed]).to eq(true)
      expect(user.reload).to have_attributes(email: "new@example.com", email_validated: false)
    end

    context "when the address is unchanged" do
      let(:email) { "old@example.com" }

      it "preserves verification" do
        expect(result.data[:changed]).to eq(false)
        expect(user.reload.email_validated).to eq(true)
      end
    end

    context "when the address is already taken" do
      let(:email) { "taken@example.com" }

      before { create(:user, email: "taken@example.com") }

      it { expect(result).to be_failure }

      it "maps uniqueness to a field error" do
        expect(result.errors.first.details).to eq("email" => "has already been taken")
      end
    end
  end
end

RSpec.describe CommandTower::Services::Admin::Users::UpdateUsername do
  describe ".call" do
    subject(:result) { described_class.call(user:, username:) }

    let(:user) { create(:user, username: "free_user") }
    let(:username) { "next_user" }

    it { expect(result).to be_success }

    context "when the username is already taken" do
      let(:username) { "taken_user" }

      before { create(:user, username: "taken_user") }

      it { expect(result).to be_failure }

      it "maps uniqueness to a field error" do
        expect(result.errors.first.details).to eq("username" => "has already been taken")
      end
    end
  end
end

RSpec.describe CommandTower::Services::Admin::Users::SetEmailValidated do
  describe ".call" do
    subject(:result) { described_class.call(user:, email_validated:) }

    let(:user) { create(:user, :unvalidated_email, email: "keep@example.com") }
    let(:email_validated) { true }

    it { expect(result).to be_success }

    it "sets validation without changing email" do
      expect(result.data[:changed]).to eq(true)
      expect(user.reload).to have_attributes(email: "keep@example.com", email_validated: true)
    end
  end
end

RSpec.describe CommandTower::Services::Admin::Users::UpdateName do
  describe ".call" do
    subject(:result) { described_class.call(user:, first_name:, last_name:) }

    let(:user) { create(:user, first_name: "Old", last_name: "Name") }
    let(:first_name) { "New" }
    let(:last_name) { "Person" }

    it "updates both name fields" do
      expect(result).to be_success
      expect(user.reload).to have_attributes(first_name: "New", last_name: "Person")
    end
  end
end
