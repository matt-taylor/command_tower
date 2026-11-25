# frozen_string_literal: true

RSpec.describe CommandTower::Auth::PasswordReset::IssueJob do
  before do
    create(:user, email: "issue-job@example.com")
    ActionMailer::Base.deliveries.clear
  end

  it "does not log its arguments" do
    expect(described_class.log_arguments).to be(false)
  end

  it "serializes only the normalized email" do
    expect(described_class.new("issue-job@example.com").serialize["arguments"]).to eq(["issue-job@example.com"])
  end

  context "when performed for a known email" do
    let(:token) { ActionMailer::Base.deliveries.last.body.to_s[/token=([A-Za-z0-9]+)/, 1] }

    before { described_class.perform_now("issue-job@example.com") }

    it "emails a reset link" do
      expect(ActionMailer::Base.deliveries.count).to eq(1)
    end

    it "keeps the token out of the serialized job" do
      expect(described_class.new("issue-job@example.com").serialize.to_s).not_to include(token)
    end
  end

  context "when performed for an unknown email" do
    it "issues no token" do
      expect { described_class.perform_now("nobody@example.com") }.not_to change(UserSecret, :count)
    end

    it "sends no mail" do
      described_class.perform_now("nobody@example.com")

      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end
end
