# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::Jwt::Config do
  subject(:config) { described_class.new }

  let(:default_secret) { described_class::DEFAULT_HMAC_SECRET }

  describe "#validate_secret!" do
    it "raises outside local when the secret is the published default" do
      config.hmac_secret = default_secret

      expect { config.validate_secret!(local: false) }
        .to raise_error(CommandTower::Errors::InsecureJwtSecretError)
    end

    it "raises outside local when the secret is blank" do
      config.hmac_secret = "  "

      expect { config.validate_secret!(local: false) }
        .to raise_error(CommandTower::Errors::InsecureJwtSecretError)
    end

    it "does not raise outside local for a private secret" do
      config.hmac_secret = "a-private-secret-value"

      expect { config.validate_secret!(local: false) }.not_to raise_error
    end

    it "does not raise in local environments with the default" do
      config.hmac_secret = default_secret

      expect { config.validate_secret!(local: true) }.not_to raise_error
    end

    it "does not raise when the escape hatch is enabled" do
      config.hmac_secret = default_secret
      config.allow_insecure_default_secret = true

      expect { config.validate_secret!(local: false) }.not_to raise_error
    end

    it "defaults the escape hatch to false" do
      expect(config.allow_insecure_default_secret).to be(false)
    end

    it "boots in the test environment" do
      expect { CommandTower.config.jwt.validate_secret! }.not_to raise_error
    end
  end
end
