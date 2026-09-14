# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::EmailTheme::Config do
  {
    canvas_background: "#f4f5f7",
    surface_background: "#ffffff",
    surface_border: "#e2e8f0",
    primary_text: "#1a202c",
    body_text: "#4a5568",
    muted_text: "#718096",
    accent: "#2b6cb0",
    text_on_accent: "#ffffff",
    primary_action: "#2b6cb0"
  }.each do |token, default_value|
    describe "##{token}" do
      around do |example|
        previous = CommandTower.config.email_theme.public_send(token)
        example.run
      ensure
        CommandTower.config.email_theme.public_send("#{token}=", previous)
      end

      it "defaults to the current unbranded value" do
        expect(CommandTower.config.email_theme.public_send(token)).to eq(default_value)
      end

      context "when a host assigns an override" do
        before { CommandTower.config.email_theme.public_send("#{token}=", "#123456") }

        it "accepts the override" do
          expect(CommandTower.config.email_theme.public_send(token)).to eq("#123456")
        end
      end

      context "when a host assigns a non-String value" do
        subject(:assign) { CommandTower.config.email_theme.public_send("#{token}=", 123) }

        it "rejects the value at configure time" do
          expect { assign }.to raise_error(ClassComposer::ValidatorError, /String/)
        end
      end
    end
  end
end
