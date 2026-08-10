# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::ChannelMailer do
  let(:build_rendered) do
    lambda do |**overrides|
      CommandTower::Messaging::Rendering::RenderedPayload.build(
        recipient_address: overrides.fetch(:recipient_address, "user@example.com"),
        subject: overrides.fetch(:subject, "Hello"),
        text_body: overrides.fetch(:text_body, "Plain body"),
        html_body: overrides.fetch(:html_body, "<p>HTML body</p>"),
      )
    end
  end

  context "under :test delivery" do
    before { ActionMailer::Base.deliveries.clear }

    before { described_class.deliver_rendered(rendered: build_rendered.call).deliver }

    it "maps a RenderedPayload into an ActionMailer message under :test delivery" do
      expect(ActionMailer::Base.deliveries.size).to eq(1)
      expect(ActionMailer::Base.deliveries.last.to).to eq(["user@example.com"])
      expect(ActionMailer::Base.deliveries.last.subject).to eq("Hello")
      expect(ActionMailer::Base.deliveries.last.text_part.body.to_s).to include("Plain body")
      expect(ActionMailer::Base.deliveries.last.html_part.body.to_s).to include("<p>HTML body</p>")
    end
  end

  it "rejects non-RenderedPayload inputs" do
    expect {
      described_class.deliver_rendered(rendered: { subject: "x" }).message
    }.to raise_error(ArgumentError)
  end

  context "when CredentialResolution SMTP username is available" do
    let(:previous_user) { CommandTower.config.credentials.smtp.user_name }
    let(:previous_pass) { CommandTower.config.credentials.smtp.password }

    before do
      ActionMailer::Base.deliveries.clear
      CommandTower.config.credentials.smtp.user_name = "from-cr@example.com"
      CommandTower.config.credentials.smtp.password = "secret"
      described_class.deliver_rendered(rendered: build_rendered.call).deliver
    end

    after do
      CommandTower.config.credentials.smtp.user_name = previous_user
      CommandTower.config.credentials.smtp.password = previous_pass
    end

    it "uses CredentialResolution SMTP username for From when available" do
      expect(ActionMailer::Base.deliveries.last.from).to eq(["from-cr@example.com"])
    end
  end
end
