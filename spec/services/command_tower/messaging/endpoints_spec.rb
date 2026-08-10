# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Endpoints do
  let(:user) { create(:user) }
  let(:owner_user_id) { user.id }

  let(:pushover_credentials) do
    lambda do |user_key: "pushover-user-key-abcd", application_token: "pushover-app-token-zzzz"|
      { user_key:, application_token: }
    end
  end

  let(:create_pushover!) do
    lambda do |**credential_overrides|
      described_class.create(
        owner_user_id:,
        channel_key: "pushover",
        credentials: pushover_credentials.call(**credential_overrides),
      )
    end
  end

  let(:insert_orphan_sms_endpoint!) do
    lambda do |address: "+15551234567"|
      encrypted = CommandTower::Messaging::Endpoints::SecretBox.encrypt(address)
      record = CommandTower::Messaging::Endpoint.new(
        user_id: owner_user_id,
        channel_key: "sms",
        lifecycle_state: "active",
        verification_state: "unverified",
        address_fingerprint: CommandTower::Messaging::Endpoints::Fingerprinter.fingerprint(address),
        masked_display_value: "***-***-#{address[-4, 4]}",
        address_ciphertext: encrypted.fetch(:ciphertext),
        encryption_key_version: encrypted.fetch(:key_version),
      )
      record.derive_uniqueness_columns!
      record.save!(validate: false)
      record
    end
  end

  describe ".create" do
    context "when creating a pushover endpoint" do
      subject(:view) { create_pushover!.call }

      let(:record) { CommandTower::Messaging::Endpoint.find(view.id) }
      let(:credential) { record.pushover_credential }

      it "creates a pushover endpoint with both credentials encrypted on the child record" do
        expect(view.channel_key).to eq("pushover")
        expect(view.lifecycle_state).to eq("active")
        expect(view.verification_state).to eq("unverified")
        expect(view.masked_display_value).to eq("#{"•" * 8}abcd")
        expect(view.credentials_configured).to be(true)
        expect(view).not_to respond_to(:address_ciphertext)
        expect(view).not_to respond_to(:user_key)
        expect(view).not_to respond_to(:application_token)

        expect(record.address_ciphertext).to be_nil
        expect(record.active_fingerprint).to eq(record.address_fingerprint)
        expect(record.single_active_slot).to eq("#{owner_user_id}:pushover")

        expect(credential).to be_present
        expect(credential.user_key_ciphertext).not_to include("pushover-user-key")
        expect(credential.application_token_ciphertext).not_to include("pushover-app-token")
        expect(credential.user_key_ciphertext).not_to eq(credential.application_token_ciphertext)
      end
    end

    context "when creating push endpoints" do
      let(:first) do
        described_class.create(owner_user_id:, channel_key: "push", address: "ExponentPushToken[aaaa1111]")
      end
      let(:second) do
        described_class.create(owner_user_id:, channel_key: "push", address: "ExponentPushToken[bbbb2222]")
      end

      before { first && second }

      it "creates push endpoints as unverified and allows multiple actives" do
        expect(first.verification_state).to eq("unverified")
        expect(first.credentials_configured).to be(true)
        expect(second.verification_state).to eq("unverified")
        expect(described_class.list(owner_user_id:, channel_key: "push").size).to eq(2)
      end
    end

    context "when credentials are supplied for push" do
      subject(:invoke) do
        described_class.create(
          owner_user_id:,
          channel_key: "push",
          address: "ExponentPushToken[aaaa1111]",
          credentials: { user_key: "x", application_token: "y" },
        )
      end

      it "rejects credentials: on push" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Endpoints::ValidationError, /does not accept credentials/)
      end
    end

    context "when address is supplied for pushover" do
      subject(:invoke) do
        described_class.create(
          owner_user_id:,
          channel_key: "pushover",
          address: "pushover-user-key-abcd",
        )
      end

      it "rejects address: on pushover" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Endpoints::ValidationError, /requires credentials/)
      end
    end

    context "when the same active credential pair is submitted twice" do
      let(:first) { create_pushover!.call }
      let(:second) { create_pushover!.call }

      before { first && second }

      it "is idempotent for the same active credential pair" do
        expect(second.id).to eq(first.id)
        expect(CommandTower::Messaging::Endpoint.active.for_owner(owner_user_id).count).to eq(1)
      end
    end

    context "when the same user key has a different application token" do
      before { create_pushover!.call(application_token: "pushover-app-token-aaaa") }

      subject(:invoke) { create_pushover!.call(application_token: "pushover-app-token-bbbb") }

      it "raises ConflictError when the same user key has a different application token" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Endpoints::ConflictError, /different credentials/)
      end
    end

    context "when a different pushover credential pair is already active" do
      before { create_pushover!.call }

      subject(:invoke) do
        create_pushover!.call(user_key: "pushover-user-key-efgh", application_token: "pushover-app-token-yyyy")
      end

      it "raises ConflictError when a different pushover credential pair is already active" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Endpoints::ConflictError)
      end
    end

    context "when credential insert fails" do
      before do
        allow(CommandTower::Messaging::Endpoints::Persistence).to receive(:create_pushover_credential!)
          .and_raise(ActiveRecord::RecordInvalid.new(CommandTower::Messaging::EndpointPushoverCredential.new))
      end

      subject(:invoke) { create_pushover!.call }

      it "rolls back parent and child when credential insert fails" do
        expect { invoke }.to raise_error(ActiveRecord::RecordInvalid)

        expect(CommandTower::Messaging::Endpoint.for_owner(owner_user_id).count).to eq(0)
        expect(CommandTower::Messaging::EndpointPushoverCredential.count).to eq(0)
      end
    end

    context "when the email channel is requested" do
      subject(:invoke) { described_class.create(owner_user_id:, channel_key: "email", address: "a@b.com") }

      it "rejects email channel create" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Endpoints::ValidationError)
      end
    end

    context "when the inbox channel is requested" do
      subject(:invoke) { described_class.create(owner_user_id:, channel_key: "inbox", address: "n/a") }

      it "rejects inbox channel create" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Endpoints::ValidationError)
      end
    end

    context "when the sms channel is requested" do
      subject(:invoke) do
        described_class.create(owner_user_id:, channel_key: "sms", address: "+15551234567")
      end

      it "rejects sms channel create" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Endpoints::ValidationError, /does not support endpoint records/)
      end
    end

    context "when a database unique conflict occurs on insert" do
      before do
        described_class.create(owner_user_id:, channel_key: "push", address: "ExponentPushToken[same9999]")

        allow(CommandTower::Messaging::Endpoint).to receive(:new).and_wrap_original do |method, *args, **kwargs|
          record = method.call(*args, **kwargs)
          allow(record).to receive(:save!) do
            raise ActiveRecord::RecordNotUnique, "Duplicate entry for key 'index_messaging_endpoints_active_fingerprint'"
          end
          record
        end

        allow(CommandTower::Messaging::Endpoints::Persistence).to receive(:find_active_by_fingerprint)
          .and_return(nil, CommandTower::Messaging::Endpoint.active.last)
      end

      subject(:view) do
        described_class.create(owner_user_id:, channel_key: "push", address: "ExponentPushToken[same9999]")
      end

      it "translates database unique conflicts into domain behavior" do
        expect(view.masked_display_value).to eq("Device registered")
      end
    end
  end

  describe ".replace" do
    context "when replacing an active pushover endpoint" do
      let(:original) { create_pushover!.call }
      let(:replaced) do
        described_class.replace(
          owner_user_id:,
          channel_key: "pushover",
          credentials: pushover_credentials.call(
            user_key: "pushover-user-key-efgh",
            application_token: "pushover-app-token-yyyy",
          ),
        )
      end
      let(:prior) { CommandTower::Messaging::Endpoint.find(original.id) }
      let(:secrets) do
        CommandTower::Messaging::Endpoints::SecretReader.read_pushover_credentials!(
          owner_user_id:,
          endpoint_id: replaced.id,
        )
      end

      before { original && replaced }

      it "retires the prior active pushover endpoint and creates a new credential pair" do
        expect(replaced.id).not_to eq(original.id)
        expect(replaced.verification_state).to eq("unverified")
        expect(replaced.masked_display_value).to eq("#{"•" * 8}efgh")
        expect(replaced.credentials_configured).to be(true)

        expect(prior.lifecycle_state).to eq("retired")
        expect(prior.active_fingerprint).to be_nil
        expect(prior.single_active_slot).to be_nil
        expect(prior.pushover_credential).to be_present

        expect(secrets).to eq(
          user_key: "pushover-user-key-efgh",
          application_token: "pushover-app-token-yyyy",
        )
      end
    end

    context "when the prior pushover endpoint was verified" do
      let(:original) { create_pushover!.call }

      before do
        CommandTower.config.messaging.pushover.adapter = "fake"
        CommandTower::Messaging::Pushover::Transport.reset_adapter!
        CommandTower::Messaging::Pushover::Adapters::FakeAdapter.reset!
        described_class.verify_pushover!(owner_user_id:, endpoint_id: original.id)
      end

      subject(:replaced) do
        described_class.replace(
          owner_user_id:,
          channel_key: "pushover",
          credentials: pushover_credentials.call(
            user_key: "pushover-user-key-new1",
            application_token: "pushover-app-token-new1",
          ),
        )
      end

      it "resets verification to unverified even when the prior endpoint was verified" do
        expect(CommandTower::Messaging::Endpoint.find(original.id).verification_state).to eq("verified")
        expect(replaced.verification_state).to eq("unverified")
        expect(replaced.verified_at).to be_nil
      end
    end

    context "when creating or replacing pushover endpoints" do
      before do
        expect(CommandTower::Messaging::Pushover::Transport).not_to receive(:validate_user!)
        expect(CommandTower::Messaging::Pushover::Transport).not_to receive(:send_test_notification!)
      end

      subject(:perform) do
        create_pushover!.call
        described_class.replace(
          owner_user_id:,
          channel_key: "pushover",
          credentials: pushover_credentials.call(
            user_key: "pushover-user-key-efgh",
            application_token: "pushover-app-token-yyyy",
          ),
        )
      end

      it "never contacts Pushover Transport during create or replace" do
        expect { perform }.not_to raise_error
      end
    end

    context "when sms replace is requested" do
      subject(:invoke) do
        described_class.replace(owner_user_id:, channel_key: "sms", address: "+15559876543")
      end

      it "rejects sms replace" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Endpoints::ValidationError, /does not support endpoint records/)
      end
    end

    context "when replacing a single push endpoint" do
      let(:endpoint_a) do
        described_class.create(owner_user_id:, channel_key: "push", address: "ExponentPushToken[aaaa1111]")
      end
      let(:endpoint_b) do
        described_class.create(owner_user_id:, channel_key: "push", address: "ExponentPushToken[bbbb2222]")
      end

      before do
        endpoint_a && endpoint_b
        described_class.replace(
          owner_user_id:,
          endpoint_id: endpoint_a.id,
          address: "ExponentPushToken[cccc3333]",
        )
      end

      it "replaces only the targeted push endpoint" do
        expect(CommandTower::Messaging::Endpoint.find(endpoint_a.id).lifecycle_state).to eq("retired")
        expect(CommandTower::Messaging::Endpoint.find(endpoint_b.id).lifecycle_state).to eq("active")
        expect(CommandTower::Messaging::Endpoint.active.for_owner(owner_user_id).for_channel("push").count).to eq(2)
      end
    end
  end

  describe ".verify_pushover!" do
    around do |example|
      previous = CommandTower.config.messaging.pushover.adapter
      CommandTower.config.messaging.pushover.adapter = "fake"
      CommandTower::Messaging::Pushover::Transport.reset_adapter!
      CommandTower::Messaging::Pushover::Adapters::FakeAdapter.reset!
      example.run
    ensure
      CommandTower.config.messaging.pushover.adapter = previous
      CommandTower::Messaging::Pushover::Transport.reset_adapter!
      CommandTower::Messaging::Pushover::Adapters::FakeAdapter.reset!
    end

    context "when validate and test notification succeed" do
      let(:view) { create_pushover!.call }

      subject(:verified) { described_class.verify_pushover!(owner_user_id:, endpoint_id: view.id) }

      it "marks verified after validate + test notification succeed" do
        expect(verified.verification_state).to eq("verified")
        expect(verified.verified_at).to be_present
        expect(CommandTower::Messaging::Pushover::Adapters::FakeAdapter.validations.size).to eq(1)
        expect(CommandTower::Messaging::Pushover::Adapters::FakeAdapter.test_notifications.size).to eq(1)
      end
    end

    context "when validate fails" do
      let(:view) { create_pushover!.call }

      before { CommandTower::Messaging::Pushover::Adapters::FakeAdapter.fail_with = :invalid_user }

      subject(:invoke) { described_class.verify_pushover!(owner_user_id:, endpoint_id: view.id) }

      it "marks failed when validate fails and does not send the test notification" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Endpoints::VerificationFailedError) { |error|
          expect(error.error_code).to eq(:invalid_user)
        }

        expect(CommandTower::Messaging::Endpoint.find(view.id).verification_state).to eq("failed")
        expect(CommandTower::Messaging::Pushover::Adapters::FakeAdapter.test_notifications).to be_empty
      end
    end

    context "when the test notification fails after a successful validate" do
      let(:call_count) { [0] }
      let(:view) { create_pushover!.call }

      before do
        allow(CommandTower::Messaging::Pushover::Transport).to receive(:validate_user!).and_return(
          CommandTower::Messaging::Pushover::Result.ok,
        )
        allow(CommandTower::Messaging::Pushover::Transport).to receive(:send_test_notification!) do
          call_count[0] += 1
          CommandTower::Messaging::Pushover::Result.failure(
            error_code: :provider_unavailable,
            error_message: "Pushover provider unavailable",
          )
        end
      end

      subject(:invoke) { described_class.verify_pushover!(owner_user_id:, endpoint_id: view.id) }

      it "marks failed when test notification fails after successful validate" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Endpoints::VerificationFailedError) { |error|
          expect(error.error_code).to eq(:provider_unavailable)
        }

        expect(CommandTower::Messaging::Endpoint.find(view.id).verification_state).to eq("failed")
        expect(call_count[0]).to eq(1)
      end
    end

    context "when the adapter is disabled" do
      let(:view) { create_pushover!.call }

      before { CommandTower.config.messaging.pushover.adapter = "disabled" }

      subject(:invoke) { described_class.verify_pushover!(owner_user_id:, endpoint_id: view.id) }

      it "raises when adapter is disabled" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Endpoints::ValidationError, /disabled/)
      end
    end

    context "when re-verifying an already verified endpoint" do
      let(:view) { create_pushover!.call }

      before { described_class.verify_pushover!(owner_user_id:, endpoint_id: view.id) }

      subject(:again) { described_class.verify_pushover!(owner_user_id:, endpoint_id: view.id) }

      it "re-verifies an already verified endpoint via reset then begin" do
        expect(again.verification_state).to eq("verified")
      end
    end

    context "when verifying a push endpoint" do
      let(:view) do
        described_class.create(owner_user_id:, channel_key: "push", address: "ExponentPushToken[aaaa1111]")
      end

      subject(:invoke) { described_class.verify_pushover!(owner_user_id:, endpoint_id: view.id) }

      it "rejects push endpoints" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Endpoints::ValidationError, /not a pushover/)
      end
    end

    context "when verifying an inactive endpoint" do
      let(:view) { create_pushover!.call }

      before { described_class.revoke(owner_user_id:, endpoint_id: view.id) }

      subject(:invoke) { described_class.verify_pushover!(owner_user_id:, endpoint_id: view.id) }

      it "rejects inactive endpoints" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Endpoints::ValidationError, /must be active/)
      end
    end
  end

  describe ".revoke" do
    context "when revoking an active endpoint" do
      let(:view) { create_pushover!.call }

      subject(:revoked) { described_class.revoke(owner_user_id:, endpoint_id: view.id) }

      let(:record) { CommandTower::Messaging::Endpoint.find(view.id) }

      it "revokes an active endpoint and clears uniqueness slots" do
        expect(revoked.lifecycle_state).to eq("revoked")
        expect(record.active_fingerprint).to be_nil
        expect(record.single_active_slot).to be_nil
        expect(record.revoked_at).to be_present
        expect(record.pushover_credential).to be_present
      end
    end

    context "when revoking an already revoked endpoint" do
      let(:view) { create_pushover!.call }
      let(:first) { described_class.revoke(owner_user_id:, endpoint_id: view.id) }
      let(:second) { described_class.revoke(owner_user_id:, endpoint_id: view.id) }

      before { first && second }

      it "is idempotent for already revoked endpoints" do
        expect(second.id).to eq(first.id)
        expect(second.lifecycle_state).to eq("revoked")
      end
    end
  end

  describe "verification intent operations" do
    context "when transitioning through begin and verified" do
      let(:view) { create_pushover!.call }
      let(:pending) { described_class.begin_verification(owner_user_id:, endpoint_id: view.id) }
      let(:verified) { described_class.mark_verified(owner_user_id:, endpoint_id: view.id) }

      before { pending && verified }

      subject(:invoke) { described_class.begin_verification(owner_user_id:, endpoint_id: view.id) }

      it "supports begin → verified and rejects illegal transitions" do
        expect(pending.verification_state).to eq("pending")
        expect(verified.verification_state).to eq("verified")
        expect(verified.verified_at).to be_present
        expect { invoke }.to raise_error(CommandTower::Messaging::Endpoints::InvalidTransitionError)
      end
    end

    context "when incrementing lock_version across verification intent transitions" do
      let!(:view) { create_pushover!.call }
      let!(:before_version) { CommandTower::Messaging::Endpoint.find(view.id).lock_version }

      subject(:after_version) do
        described_class.begin_verification(owner_user_id:, endpoint_id: view.id)
        CommandTower::Messaging::Endpoint.find(view.id).lock_version
      end

      it "increments lock_version across verification intent transitions" do
        expect(after_version).to be > before_version
      end
    end
  end

  describe "mark_invalid" do
    context "when marking an active endpoint invalid" do
      let(:view) { create_pushover!.call }

      subject(:invalid) { described_class.mark_invalid(owner_user_id:, endpoint_id: view.id) }

      let(:record) { CommandTower::Messaging::Endpoint.find(view.id) }

      it "marks an active endpoint invalid and clears uniqueness slots" do
        expect(invalid.lifecycle_state).to eq("invalid")
        expect(record.active_fingerprint).to be_nil
        expect(record.single_active_slot).to be_nil
      end
    end
  end

  describe "SecretReader" do
    context "when reading push address secrets" do
      let(:view) do
        described_class.create(owner_user_id:, channel_key: "push", address: "ExponentPushToken[abcd1234]")
      end

      subject(:plaintext) do
        CommandTower::Messaging::Endpoints::SecretReader.read!(
          owner_user_id:,
          endpoint_id: view.id,
        )
      end

      it "decrypts push address secrets via read!" do
        expect(plaintext).to eq("ExponentPushToken[abcd1234]")
        expect(view.members).not_to include(:address_ciphertext)
      end
    end

    context "when reading pushover credentials" do
      let(:view) { create_pushover!.call }

      subject(:secrets) do
        CommandTower::Messaging::Endpoints::SecretReader.read_pushover_credentials!(
          owner_user_id:,
          endpoint_id: view.id,
        )
      end

      it "rejects read! for pushover and decrypts the credential pair via read_pushover_credentials!" do
        expect {
          CommandTower::Messaging::Endpoints::SecretReader.read!(
            owner_user_id:,
            endpoint_id: view.id,
          )
        }.to raise_error(CommandTower::Messaging::Endpoints::ValidationError, /read_pushover_credentials/)

        expect(secrets).to eq(
          user_key: "pushover-user-key-abcd",
          application_token: "pushover-app-token-zzzz",
        )
      end
    end
  end

  describe "supports_endpoint_records=false contract" do
    CommandTower::Messaging::Channels.definitions
      .reject(&:supports_endpoint_records)
      .map(&:key)
      .each do |channel_key|
      context "when channel is #{channel_key}" do
        subject(:create_invoke) do
          described_class.create(owner_user_id:, channel_key:, address: "unused-address-value")
        end

        subject(:list_invoke) { described_class.list(owner_user_id:, channel_key:) }

        it "rejects create for unsupported catalog channel" do
          expect { create_invoke }.to raise_error(CommandTower::Messaging::Endpoints::ValidationError)
        end

        it "rejects list-by-channel for unsupported catalog channel" do
          expect { list_invoke }.to raise_error(CommandTower::Messaging::Endpoints::ValidationError)
        end
      end
    end

    context "when orphan unsupported rows exist" do
      let!(:push) do
        described_class.create(owner_user_id:, channel_key: "push", address: "ExponentPushToken[keep0001]")
      end
      let!(:orphan) { insert_orphan_sms_endpoint!.call }

      subject(:listed) { described_class.list(owner_user_id:) }

      it "excludes orphan unsupported rows from unfiltered list" do
        expect(listed.map(&:id)).to eq([push.id])
        expect(listed.map(&:channel_key)).not_to include("sms")
        expect(CommandTower::Messaging::Endpoint.exists?(orphan.id)).to be(true)
      end
    end

    context "when orphan unsupported rows are accessed directly" do
      let!(:orphan) { insert_orphan_sms_endpoint!.call }

      it "hides orphan unsupported rows from show/revoke/verify/secret read" do
        expect {
          described_class.show(owner_user_id:, endpoint_id: orphan.id)
        }.to raise_error(CommandTower::Messaging::Endpoints::NotFoundError)

        expect {
          described_class.revoke(owner_user_id:, endpoint_id: orphan.id)
        }.to raise_error(CommandTower::Messaging::Endpoints::NotFoundError)

        expect {
          described_class.mark_invalid(owner_user_id:, endpoint_id: orphan.id)
        }.to raise_error(CommandTower::Messaging::Endpoints::NotFoundError)

        expect {
          described_class.begin_verification(owner_user_id:, endpoint_id: orphan.id)
        }.to raise_error(CommandTower::Messaging::Endpoints::NotFoundError)

        expect {
          CommandTower::Messaging::Endpoints::SecretReader.read!(
            owner_user_id:,
            endpoint_id: orphan.id,
          )
        }.to raise_error(CommandTower::Messaging::Endpoints::NotFoundError)
      end
    end
  end

  describe "SecretBox" do
    context "when the production secret ENV var is missing" do
      let(:box) { CommandTower::Messaging::Endpoints::SecretBox.allocate }

      before do
        allow(box).to receive(:production_like?).and_return(true)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("COMMAND_TOWER_MESSAGING_ENDPOINT_SECRET").and_return("")
      end

      subject(:invoke) { box.send(:root_secret) }

      it "fails fast when production secret is missing" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Endpoints::SecretBox::MissingSecretError)
      end
    end

    context "when encrypting distinct purposes" do
      let(:plaintext) { "shared-secret-value-1234" }
      let(:user_key_ciphertext) do
        CommandTower::Messaging::Endpoints::SecretBox.encrypt(
          plaintext,
          purpose: CommandTower::Messaging::Endpoints::SecretBox::PUSHOVER_USER_KEY_PURPOSE,
        )
      end
      let(:application_token_ciphertext) do
        CommandTower::Messaging::Endpoints::SecretBox.encrypt(
          plaintext,
          purpose: CommandTower::Messaging::Endpoints::SecretBox::PUSHOVER_APPLICATION_TOKEN_PURPOSE,
        )
      end
      let(:decrypted) do
        CommandTower::Messaging::Endpoints::SecretBox.decrypt(
          user_key_ciphertext.fetch(:ciphertext),
          purpose: CommandTower::Messaging::Endpoints::SecretBox::PUSHOVER_USER_KEY_PURPOSE,
        )
      end

      it "derives independent ciphertexts for distinct purposes" do
        expect(user_key_ciphertext.fetch(:ciphertext)).not_to eq(application_token_ciphertext.fetch(:ciphertext))
        expect(decrypted).to eq(plaintext)
      end
    end
  end
end
