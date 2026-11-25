# frozen_string_literal: true

RSpec.describe CommandTower::Auth::EmailVerification::IssueJob do
  let(:user) { create(:user, :unvalidated_email) }

  before { ActionMailer::Base.deliveries.clear }

  it "does not log its arguments" do
    expect(described_class.log_arguments).to be(false)
  end

  it "serializes only the user id" do
    expect(described_class.new(user.id).serialize["arguments"]).to eq([user.id])
  end

  context "when performed for an unverified user" do
    let(:code) { ActionMailer::Base.deliveries.last.body.to_s[/>\s*(\d+)\s*</, 1] }

    before { described_class.perform_now(user.id) }

    it "emails a code" do
      expect(ActionMailer::Base.deliveries.count).to eq(1)
    end

    it "delivers a numeric code" do
      expect(code).to be_present
    end

    it "keeps the code out of the serialized job" do
      expect(described_class.new(user.id).serialize.to_s).not_to include(code.to_s)
    end
  end

  context "when the user is already verified" do
    let(:user) { create(:user) }

    it "sends no mail" do
      described_class.perform_now(user.id)

      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  context "when the user no longer exists" do
    it "sends no mail" do
      described_class.perform_now(0)

      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end
end
