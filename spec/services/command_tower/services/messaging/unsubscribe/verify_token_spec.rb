# frozen_string_literal: true

RSpec.describe CommandTower::Services::Messaging::Unsubscribe::VerifyToken, :aggregate_failures do
  include ActiveSupport::Testing::TimeHelpers

  let(:issue) { CommandTower::Services::Messaging::Unsubscribe::IssueToken }
  let(:verifier) { CommandTower::Messaging::Unsubscribe::TokenVerifier.verifier }
  let!(:token) { issue.call(user_id: 7, notification_type_key: "class_canceled").data[:token] }

  context "with a fresh token" do
    subject(:result) { described_class.call(token:) }

    it "round-trips the user id and type key" do
      expect(result).to be_success
      expect(result.data).to include(user_id: 7, notification_type_key: "class_canceled")
    end
  end

  context "when 89 days have passed" do
    before { travel_to(89.days.from_now) }

    it "still verifies" do
      expect(described_class.call(token:)).to be_success
    end
  end

  context "when 91 days have passed" do
    before { travel_to(91.days.from_now) }

    it "has expired" do
      expect(described_class.call(token:)).to be_failure
    end
  end

  it "rejects a tampered token" do
    expect(described_class.call(token: "#{token}x")).to be_failure
    expect(described_class.call(token: token.reverse)).to be_failure
  end

  context "when signed for another purpose" do
    let(:other) { verifier.generate({ u: 7, t: "class_canceled" }, purpose: "something_else") }

    it "is rejected" do
      expect(described_class.call(token: other)).to be_failure
    end
  end

  context "when signed by another verifier" do
    let(:other) do
      Rails.application.message_verifier("other").generate({ u: 7, t: "class_canceled" }, purpose: "unsubscribe")
    end

    it "is rejected" do
      expect(described_class.call(token: other)).to be_failure
    end
  end

  context "with a malformed payload" do
    let(:bad) { verifier.generate({ u: "7", t: "" }, purpose: "unsubscribe") }

    it "is rejected" do
      expect(described_class.call(token: bad)).to be_failure
    end
  end

  context "when the token is bad in different ways" do
    let(:errors) { [token.reverse, "", "garbage"].map { |value| described_class.call(token: value).errors.first } }

    it "fails every case with the same error and no detail beyond the token key" do
      expect(errors.map(&:class).uniq.size).to eq(1)
    end
  end

  context "with an unsubscribe_secret" do
    let!(:overridden) do
      CommandTower.config.messaging.compliance.unsubscribe_secret = "override-secret-for-spec"
      issue.call(user_id: 7, notification_type_key: "class_canceled").data[:token]
    end

    after { CommandTower.config.messaging.compliance.unsubscribe_secret = nil }

    it "round-trips with the override" do
      expect(described_class.call(token: overridden)).to be_success
    end

    context "when the override is removed" do
      before { CommandTower.config.messaging.compliance.unsubscribe_secret = nil }

      it "does not verify under the derived key" do
        expect(described_class.call(token: overridden)).to be_failure
      end
    end
  end
end
