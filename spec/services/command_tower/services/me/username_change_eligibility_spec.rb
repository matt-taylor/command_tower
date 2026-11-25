# frozen_string_literal: true

RSpec.describe CommandTower::Services::Me::UsernameChangeEligibility do
  describe ".eligible?" do
    subject(:eligible) { described_class.eligible?(user) }

    let(:user) { create(:user, username: username) }
    let(:username) { nil }
    let(:self_service) { true }
    let(:self_change) { false }

    before do
      allow(CommandTower.config.username).to receive_messages(self_service:, self_change:)
    end

    context "when self_service is off" do
      let(:self_service) { false }

      it { is_expected.to be(false) }
    end

    context "when the user has no username" do
      it { is_expected.to be(true) }
    end

    context "when the user has a username and self_change is off" do
      let(:username) { "existing_name" }

      it { is_expected.to be(false) }
    end

    context "when the user has a username and self_change is on" do
      let(:username) { "existing_name" }
      let(:self_change) { true }

      it { is_expected.to be(true) }
    end

    context "when the user is deleted" do
      let(:self_change) { true }

      before { allow(user).to receive(:deleted?).and_return(true) }

      it { is_expected.to be(false) }
    end
  end
end
