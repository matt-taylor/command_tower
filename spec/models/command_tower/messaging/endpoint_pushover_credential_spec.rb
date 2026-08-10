# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::EndpointPushoverCredential do
  describe "factory" do
    subject(:credential) { create(:messaging_endpoint_pushover_credential) }

    it "is valid and associated to a pushover endpoint" do
      expect(credential).to be_persisted
      expect(credential.endpoint).to be_persisted
      expect(credential.endpoint.channel_key).to eq("pushover")
      expect(credential.user_key_ciphertext).to be_present
      expect(credential.application_token_ciphertext).to be_present
      expect(credential.encryption_key_version).to be_present
    end

    it "stores ciphertext rather than plaintext credentials" do
      expect(credential.user_key_ciphertext).not_to include("pushover-user-key-abcd")
      expect(credential.application_token_ciphertext).not_to include("pushover-app-token-zzzz")
      expect(credential.attributes.values.map(&:to_s).join).not_to include("pushover-user-key-abcd")
    end
  end

  describe "associations and validations" do
    subject(:credential) do
      build(
        :messaging_endpoint_pushover_credential,
        endpoint:,
        user_key_ciphertext:,
        application_token_ciphertext:,
        encryption_key_version:,
      )
    end

    let(:endpoint) { create(:messaging_endpoint, :pushover) }
    let(:user_key_ciphertext) do
      CommandTower::Messaging::Endpoints::SecretBox.encrypt(
        "pushover-user-key-abcd",
        purpose: CommandTower::Messaging::Endpoints::SecretBox::PUSHOVER_USER_KEY_PURPOSE,
      ).fetch(:ciphertext)
    end
    let(:application_token_ciphertext) do
      CommandTower::Messaging::Endpoints::SecretBox.encrypt(
        "pushover-app-token-zzzz",
        purpose: CommandTower::Messaging::Endpoints::SecretBox::PUSHOVER_APPLICATION_TOKEN_PURPOSE,
      ).fetch(:ciphertext)
    end
    let(:encryption_key_version) { CommandTower::Messaging::Endpoints::SecretBox.key_version }

    it "belongs to endpoint" do
      expect(credential.endpoint).to eq(endpoint)
    end

    context "when user_key_ciphertext is blank" do
      let(:user_key_ciphertext) { nil }

      it "is invalid" do
        expect(credential).not_to be_valid
        expect(credential.errors[:user_key_ciphertext]).to be_present
      end
    end

    context "when application_token_ciphertext is blank" do
      let(:application_token_ciphertext) { nil }

      it "is invalid" do
        expect(credential).not_to be_valid
        expect(credential.errors[:application_token_ciphertext]).to be_present
      end
    end

    context "when encryption_key_version is blank" do
      let(:encryption_key_version) { nil }

      it "is invalid" do
        expect(credential).not_to be_valid
        expect(credential.errors[:encryption_key_version]).to be_present
      end
    end
  end

  describe "public encryption round-trip via SecretBox" do
    subject(:decrypted_user_key) do
      CommandTower::Messaging::Endpoints::SecretBox.decrypt(
        credential.user_key_ciphertext,
        purpose: CommandTower::Messaging::Endpoints::SecretBox::PUSHOVER_USER_KEY_PURPOSE,
      )
    end

    let(:credential) { create(:messaging_endpoint_pushover_credential) }

    it "decrypts the factory ciphertext with the public SecretBox API" do
      expect(decrypted_user_key).to eq("pushover-user-key-abcd")
    end
  end
end
