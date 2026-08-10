# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Execution::Adapters::Email::Configuration do
  let(:with_delivery_method) do
    lambda do |method, &block|
      previous = CommandTower.config.email.delivery_method
      CommandTower.config.email.delivery_method = method
      block.call
    ensure
      CommandTower.config.email.delivery_method = previous
    end
  end

  let(:with_smtp_settings) do
    lambda do |overrides, &block|
      previous = Rails.configuration.action_mailer.smtp_settings.dup
      Rails.configuration.action_mailer.smtp_settings = previous.merge(overrides)
      block.call
    ensure
      Rails.configuration.action_mailer.smtp_settings = previous
    end
  end

  it "treats :test as configured" do
    with_delivery_method.call(:test) do
      expect(described_class.email_configured?).to eq(true)
    end
  end

  it "treats :smtp with a complete contract as configured" do
    with_delivery_method.call(:smtp) do
      with_smtp_settings.call(
        address: "smtp.example.com",
        port: 587,
        user_name: "sender@example.com",
        password: "secret",
        authentication: "plain",
        enable_starttls_auto: true,
      ) do
        expect(described_class.email_configured?).to eq(true)
      end
    end
  end

  it "treats :smtp with blank credentials as unconfigured" do
    with_delivery_method.call(:smtp) do
      with_smtp_settings.call(
        address: "smtp.example.com",
        port: 587,
        user_name: "",
        password: "",
        authentication: "plain",
        enable_starttls_auto: true,
      ) do
        expect(described_class.email_configured?).to eq(false)
      end
    end
  end

  it "fails closed for unknown delivery methods" do
    with_delivery_method.call(:letter_opener) do
      expect(described_class.email_configured?).to eq(false)
    end
  end
end
