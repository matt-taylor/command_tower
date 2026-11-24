# frozen_string_literal: true

# Regression guard (design D19, 13.1 #5): without a host `config/ui_tokens.json`,
# ERB emails for undefined types and the auth mailers keep today's exact colours.
RSpec.describe "Email output without a host token file", :messaging_accept do # rubocop:disable RSpec/DescribeClass
  let(:legacy_theme) do
    {
      canvas_background: "#f4f5f7", surface_background: "#ffffff", surface_border: "#e2e8f0",
      primary_text: "#1a202c", body_text: "#4a5568", muted_text: "#718096",
      accent: "#2b6cb0", text_on_accent: "#ffffff", primary_action: "#2b6cb0"
    }
  end
  let(:communication) do
    create(:messaging_communication, user: create(:user, email: "recipient@example.com"), title: "Hello",
                                     body: "Body", metadata: { "deep_link" => "https://example.com/p" })
  end
  let(:erb_html) do
    CommandTower::Messaging::Rendering::ChannelRenderer.render(
      communication:, channel_key: "email", recipient_address: "recipient@example.com"
    ).html_body
  end
  let(:ada) { build(:user, first_name: "Ada") }

  let(:delivered_html) do
    html_part = ActionMailer::Base.deliveries.last.html_part
    html_part&.body&.to_s.presence || ActionMailer::Base.deliveries.last.body.to_s
  end

  before { ActionMailer::Base.deliveries.clear }

  it "keeps the Resolver output identical to the legacy theme" do
    expect(CommandTower::EmailTheme::Resolver.resolve).to include(legacy_theme)
  end

  it "renders the undefined-type ERB email with the legacy colours" do
    expect(erb_html).to include(
      "background-color: #f4f5f7", "background-color: #ffffff", "border: 1px solid #e2e8f0",
      "color: #1a202c", "color: #4a5568", "color: #2b6cb0"
    )
  end

  it "renders the password reset mailer with the legacy colours" do
    CommandTower::PasswordResetMailer.reset_password("to@example.com", ada, "tok").deliver_now

    expect(delivered_html).to include(
      "background-color: #f4f5f7", "background-color: #ffffff", "background: #2b6cb0",
      "border: 2px dashed #e2e8f0", "background-color: #2b6cb0"
    )
  end

  it "renders the email verification mailer with the legacy colours" do
    CommandTower::EmailVerificationMailer.verify_email("to@example.com", ada, "tok").deliver_now

    expect(delivered_html).to include("background-color: #f4f5f7", "background-color: #ffffff")
  end
end
