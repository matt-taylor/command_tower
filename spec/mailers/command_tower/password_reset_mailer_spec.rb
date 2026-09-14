# frozen_string_literal: true

RSpec.describe CommandTower::PasswordResetMailer do
  let(:user) { build(:user, first_name: "Ada", last_name: "Lovelace") }

  before { ActionMailer::Base.deliveries.clear }

  context "when config.email_theme is left at its default (no host override)" do
    let(:theme) { CommandTower::EmailTheme::Resolver.resolve }

    subject(:html_body) do
      described_class.reset_password("to@example.com", user, "reset-token-123").deliver_now
      ActionMailer::Base.deliveries.last.html_part&.body&.to_s.presence ||
        ActionMailer::Base.deliveries.last.body.to_s
    end

    it "renders CT's own default email_theme token values" do # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
      expect(html_body).to include("background-color: #{theme[:canvas_background]}")
      expect(html_body).to include("background-color: #{theme[:surface_background]}")
      expect(html_body).to include("background: #{theme[:accent]}")
      expect(html_body).to include("color: #{theme[:text_on_accent]}")
      expect(html_body).to include("border: 2px dashed #{theme[:surface_border]}")
      expect(html_body).to include("background-color: #{theme[:primary_action]}")
    end
  end

  context "when a host has overridden config.email_theme.accent" do
    around do |example|
      previous = CommandTower.config.email_theme.accent
      CommandTower.config.email_theme.accent = "#123456"
      example.run
    ensure
      CommandTower.config.email_theme.accent = previous
    end

    subject(:html_body) do
      described_class.reset_password("to@example.com", user, "reset-token-123").deliver_now
      ActionMailer::Base.deliveries.last.html_part&.body&.to_s.presence ||
        ActionMailer::Base.deliveries.last.body.to_s
    end

    it "renders the overridden theme value, proving the template reads the resolver live" do
      expect(html_body).to include("background: #123456")
      expect(html_body).not_to include("background: #2b6cb0")
    end
  end

  context "when delivering a reset token" do
    before { described_class.reset_password("to@example.com", user, "unique-reset-token").deliver_now }

    it "includes the reset token in the HTML body" do
      expect(
        ActionMailer::Base.deliveries.last.html_part&.body&.to_s.presence ||
          ActionMailer::Base.deliveries.last.body.to_s
      ).to include("unique-reset-token")
    end
  end
end
