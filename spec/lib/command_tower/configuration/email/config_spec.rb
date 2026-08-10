# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::Email::Config do
  subject(:email) { CommandTower.config.email }

  it "does not expose legacy SMTP credential accessors" do
    expect(email).not_to respond_to(:user_name)
    expect(email).not_to respond_to(:password)
    expect(email).not_to respond_to(:user_name=)
    expect(email).not_to respond_to(:password=)
  end

  it "retains non-secret SMTP behavior knobs" do
    expect(email).to respond_to(:address)
    expect(email).to respond_to(:port)
    expect(email).to respond_to(:authentication)
    expect(email).to respond_to(:enable_starttls_auto)
    expect(email).to respond_to(:delivery_method)
  end

  describe "#gmail!" do
    let(:previous) do
      {
        address: email.address,
        port: email.port,
        authentication: email.authentication,
        enable_starttls_auto: email.enable_starttls_auto,
      }
    end

    before do
      email.gmail!(
        address: "smtp.example.test",
        port: 465,
        authentication: "login",
        enable_starttls_auto: false,
      )
    end

    after do
      email.address = previous[:address]
      email.port = previous[:port]
      email.authentication = previous[:authentication]
      email.enable_starttls_auto = previous[:enable_starttls_auto]
    end

    it "sets only non-secret Gmail SMTP behavior" do
      expect(email.address).to eq("smtp.example.test")
      expect(email.port).to eq(465)
      expect(email.authentication).to eq("login")
      expect(email.enable_starttls_auto).to eq(false)
      expect(email.method(:gmail!).parameters.map(&:last)).to eq(
        %i[port address authentication enable_starttls_auto]
      )
    end
  end
end
