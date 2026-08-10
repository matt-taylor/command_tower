# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Endpoint do
  let(:user) { create(:user) }

  let(:build_push_attrs) do
    lambda do |address:|
      validated = CommandTower::Messaging::Endpoints::Validators.validate!(
        channel_key: "push",
        address:,
      )
      encrypted = CommandTower::Messaging::Endpoints::SecretBox.encrypt(validated.normalized_address)
      {
        user_id: user.id,
        channel_key: "push",
        lifecycle_state: "active",
        verification_state: "unverified",
        address_fingerprint: CommandTower::Messaging::Endpoints::Fingerprinter.fingerprint(
          validated.normalized_address,
        ),
        masked_display_value: validated.masked_display_value,
        address_ciphertext: encrypted.fetch(:ciphertext),
        encryption_key_version: encrypted.fetch(:key_version),
      }
    end
  end

  let(:build_pushover_parent_attrs) do
    lambda do |user_key: "pushover-user-key-abcd", application_token: "pushover-app-token-zzzz"|
      validated = CommandTower::Messaging::Endpoints::Validators.validate_pushover_credentials!(
        { user_key:, application_token: },
      )
      {
        user_id: user.id,
        channel_key: "pushover",
        lifecycle_state: "active",
        verification_state: "unverified",
        address_fingerprint: CommandTower::Messaging::Endpoints::Fingerprinter.fingerprint(
          validated.pair_fingerprint_material,
        ),
        masked_display_value: validated.masked_display_value,
        address_ciphertext: nil,
        encryption_key_version: CommandTower::Messaging::Endpoints::SecretBox.key_version,
      }
    end
  end

  context "when deriving uniqueness columns for active pushover" do
    subject(:record) { described_class.new(build_pushover_parent_attrs.call) }

    before { record.derive_uniqueness_columns! }

    it "derives active uniqueness columns for pushover" do
      expect(record.active_fingerprint).to eq(record.address_fingerprint)
      expect(record.single_active_slot).to eq("#{user.id}:pushover")
    end
  end

  context "when pushover is retired" do
    subject(:record) { described_class.new(build_pushover_parent_attrs.call) }

    before do
      record.derive_uniqueness_columns!
      record.lifecycle_state = "retired"
      record.derive_uniqueness_columns!
    end

    it "clears uniqueness columns when retired" do
      expect(record.active_fingerprint).to be_nil
      expect(record.single_active_slot).to be_nil
    end
  end

  context "when deriving uniqueness columns for push" do
    subject(:record) { described_class.new(build_push_attrs.call(address: "ExponentPushToken[zzzz9999]")) }

    before { record.derive_uniqueness_columns! }

    it "does not set single_active_slot for push" do
      expect(record.active_fingerprint).to be_present
      expect(record.single_active_slot).to be_nil
    end
  end

  context "when channel_key is email or sms" do
    subject(:record) { described_class.new(build_pushover_parent_attrs.call.merge(channel_key: "email")) }

    let(:sms) { described_class.new(build_pushover_parent_attrs.call.merge(channel_key: "sms")) }

    it "rejects email and sms channel keys" do
      expect(record).not_to be_valid
      expect(record.errors[:channel_key]).to be_present

      expect(sms).not_to be_valid
      expect(sms.errors[:channel_key]).to be_present
    end
  end

  context "when validating address ciphertext requirements" do
    subject(:push) do
      described_class.new(
        build_push_attrs.call(address: "ExponentPushToken[zzzz9999]").merge(address_ciphertext: nil),
      )
    end

    let(:pushover) do
      described_class.new(
        build_pushover_parent_attrs.call.merge(
          address_ciphertext: CommandTower::Messaging::Endpoints::SecretBox.encrypt("nope").fetch(:ciphertext),
        ),
      )
    end

    it "requires address ciphertext for push and forbids it for pushover" do
      expect(push).not_to be_valid
      expect(push.errors[:address_ciphertext]).to be_present

      expect(pushover).not_to be_valid
      expect(pushover.errors[:address_ciphertext]).to be_present
    end
  end

  context "when destroying a pushover endpoint" do
    let!(:view) do
      CommandTower::Messaging::Endpoints.create(
        owner_user_id: user.id,
        channel_key: "pushover",
        credentials: {
          user_key: "pushover-user-key-abcd",
          application_token: "pushover-app-token-zzzz",
        },
      )
    end

    let(:record) { described_class.find(view.id) }
    let(:credential_id) { record.pushover_credential.id }

    before { record.destroy! }

    it "destroys the pushover credential child when the endpoint is destroyed" do
      expect(CommandTower::Messaging::EndpointPushoverCredential.exists?(credential_id)).to be(false)
    end
  end
end
