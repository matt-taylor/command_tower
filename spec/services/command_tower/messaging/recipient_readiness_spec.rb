# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::RecipientReadiness do
  let(:user) { create(:user, email: "ready@example.com", email_validated: true) }
  let(:platform_enabled_channels) { %w[email sms push pushover] }

  let(:for_channel) do
    lambda do |key, enabled: platform_enabled_channels, recipient: user|
      described_class.for_channel(
        recipient_id: recipient.id,
        channel_key: key,
        platform_enabled_channels: enabled,
      )
    end
  end

  let(:for_recipient) do
    lambda do |enabled: platform_enabled_channels, recipient: user|
      described_class.for_recipient(
        recipient_id: recipient.id,
        platform_enabled_channels: enabled,
      )
    end
  end

  let(:create_push!) do
    lambda do |address:, verification: "unverified", lifecycle: "active"|
      view = CommandTower::Messaging::Endpoints.create(
        owner_user_id: user.id,
        channel_key: "push",
        address:,
      )
      record = CommandTower::Messaging::Endpoint.find(view.id)
      if lifecycle != "active" || verification != "unverified"
        record.lifecycle_state = lifecycle
        record.verification_state = verification
        record.verified_at = Time.current if verification == "verified"
        record.revoked_at = Time.current if lifecycle == "revoked"
        record.derive_uniqueness_columns!
        record.save!
      end
      record
    end
  end

  describe ".for_channel" do
    context "when the channel is unknown" do
      subject(:invoke) { for_channel.call("fax") }

      it "raises UnknownChannelError" do
        expect { invoke }.to raise_error(CommandTower::Messaging::RecipientReadiness::UnknownChannelError)
      end
    end

    context "when the recipient is missing" do
      subject(:invoke) do
        described_class.for_channel(
          recipient_id: 0,
          channel_key: "email",
          platform_enabled_channels: %w[email],
        )
      end

      it "raises RecipientNotFoundError" do
        expect { invoke }.to raise_error(CommandTower::Messaging::RecipientReadiness::RecipientNotFoundError)
      end
    end

    context "inbox" do
      subject(:result) { for_channel.call("inbox", enabled: []) }

      it "is ready when the recipient exists" do
        expect(result).to have_attributes(
          ready: true,
          platform_enabled: true,
          platform_configured: true,
          recipient_ready: true,
          status: "ready",
          reason_codes: [],
          endpoint_count: 0,
          eligible_endpoint_ids: [],
          verification_required: false,
        )
      end
    end

    context "email identity" do
      before do
        allow(
          CommandTower::Messaging::Execution::Adapters::Email::Configuration,
        ).to receive(:email_configured?).and_return(true)
      end

      context "when email is present and validated" do
        subject(:result) { for_channel.call("email") }

        it "is ready" do
          expect(result).to have_attributes(
            ready: true,
            recipient_ready: true,
            reason_codes: [],
            verification_required: false,
          )
        end
      end

      context "when email is blank" do
        before { user.update_columns(email: "") }

        subject(:result) { for_channel.call("email") }

        it "reports identity_missing" do
          expect(result.recipient_ready).to be(false)
          expect(result.reason_codes).to include("identity_missing")
        end
      end

      context "when email is not validated" do
        before { user.update!(email_validated: false) }

        subject(:result) { for_channel.call("email") }

        it "reports identity_unverified" do
          expect(result.recipient_ready).to be(false)
          expect(result.reason_codes).to include("identity_unverified")
          expect(result.verification_required).to be(true)
        end
      end

      context "when email is not platform-enabled" do
        subject(:result) { for_channel.call("email", enabled: []) }

        it "reports platform_disabled" do
          expect(result.platform_enabled).to be(false)
          expect(result.ready).to be(false)
          expect(result.reason_codes).to include("platform_disabled")
        end
      end

      context "when the email adapter is not configured" do
        before do
          allow(
            CommandTower::Messaging::Execution::Adapters::Email::Configuration,
          ).to receive(:email_configured?).and_return(false)
        end

        subject(:result) { for_channel.call("email") }

        it "reports platform_unconfigured" do
          expect(result.platform_configured).to be(false)
          expect(result.ready).to be(false)
          expect(result.reason_codes).to include("platform_unconfigured")
        end
      end
    end

    context "sms identity" do
      context "when phone columns exist but phone is absent" do
        subject(:result) { for_channel.call("sms") }

        it "reports identity_missing" do
          expect(result.recipient_ready).to be(false)
          expect(result.reason_codes).to include("identity_missing")
          expect(result.reason_codes).not_to include("identity_unavailable")
          expect(result.platform_configured).to be(false)
          expect(result.reason_codes).to include("platform_unconfigured")
          expect(result.eligible_endpoint_ids).to eq([])
        end
      end

      context "when an orphan SMS endpoint record exists" do
        subject(:result) { for_channel.call("sms") }

        before do
          encrypted = CommandTower::Messaging::Endpoints::SecretBox.encrypt("+15551234567")
          orphan = CommandTower::Messaging::Endpoint.new(
            user_id: user.id,
            channel_key: "sms",
            lifecycle_state: "active",
            verification_state: "verified",
            verified_at: Time.current,
            address_fingerprint: CommandTower::Messaging::Endpoints::Fingerprinter.fingerprint("+15551234567"),
            masked_display_value: "***-***-4567",
            address_ciphertext: encrypted.fetch(:ciphertext),
            encryption_key_version: encrypted.fetch(:key_version),
          )
          orphan.derive_uniqueness_columns!
          orphan.save!(validate: false)
        end

        it "rejects SMS endpoint create and ignores orphan endpoints for readiness" do
          expect {
            CommandTower::Messaging::Endpoints.create(
              owner_user_id: user.id,
              channel_key: "sms",
              address: "+15551234567",
            )
          }.to raise_error(CommandTower::Messaging::Endpoints::ValidationError)

          expect(result.recipient_ready).to be(false)
          expect(result.reason_codes).to include("identity_missing")
          expect(result.reason_codes).not_to include("identity_unavailable")
          expect(result.endpoint_count).to eq(0)
        end
      end

      context "when Twilio SMS configuration is complete" do
        before do
          allow(
            CommandTower::Messaging::Execution::Adapters::Sms::Configuration,
          ).to receive(:sms_configured?).and_return(true)
          user.update!(phone_number: "+14155552671", phone_number_validated: true)
        end

        subject(:result) { for_channel.call("sms") }

        it "reports platform_configured" do
          expect(result.platform_configured).to be(true)
          expect(result.reason_codes).not_to include("platform_unconfigured")
        end
      end

      context "when the SMS adapter is not configured" do
        before do
          allow(
            CommandTower::Messaging::Execution::Adapters::Sms::Configuration,
          ).to receive(:sms_configured?).and_return(false)
        end

        subject(:result) { for_channel.call("sms") }

        it "does not treat fake adapter as platform_configured" do
          expect(result.platform_configured).to be(false)
          expect(result.reason_codes).to include("platform_unconfigured")
        end
      end

      context "when IdentityFacts reports phone support" do
        let(:facts) do
          CommandTower::Messaging::RecipientReadiness::IdentityFacts.new(
            email_supported: true,
            email_present: true,
            email_validated: true,
            phone_supported: true,
            phone_present: true,
            phone_number_validated: true,
          )
        end

        before do
          allow(CommandTower::Messaging::RecipientReadiness::IdentityFacts).to receive(:for_user).and_return(facts)
        end

        subject(:result) { for_channel.call("sms") }

        it "evaluates phone facts" do
          expect(result.recipient_ready).to be(true)
          expect(result.reason_codes).not_to include("identity_unavailable")
        end
      end

      context "when phone is supported but absent" do
        subject(:result) { for_channel.call("sms") }

        it "reports identity_missing" do
          expect(result.reason_codes).to include("identity_missing")
          expect(result.reason_codes).not_to include("identity_unavailable")
        end
      end

      context "when phone is present but not validated" do
        before { user.update!(phone_number: "+14155552671", phone_number_validated: false) }

        subject(:result) { for_channel.call("sms") }

        it "reports identity_unverified" do
          expect(result.reason_codes).to include("identity_unverified")
          expect(result.reason_codes).not_to include("identity_unavailable")
          expect(result.reason_codes).not_to include("identity_missing")
        end
      end
    end

    context "push endpoints" do
      context "when no endpoints exist" do
        subject(:result) { for_channel.call("push") }

        it "reports endpoint_missing" do
          expect(result.recipient_ready).to be(false)
          expect(result.reason_codes).to include("endpoint_missing")
          expect(result.platform_configured).to be(false)
        end
      end

      context "when only active unverified devices exist" do
        before { create_push!.call(address: "ExponentPushToken[aaaa1111]") }

        subject(:result) { for_channel.call("push") }

        it "reports endpoint_unverified" do
          expect(result.recipient_ready).to be(false)
          expect(result.reason_codes).to include("endpoint_unverified")
          expect(result.endpoint_count).to eq(1)
          expect(result.eligible_endpoint_count).to eq(0)
        end
      end

      context "when any device is active and verified" do
        let!(:verified) do
          create_push!.call(address: "ExponentPushToken[aaaa1111]")
          create_push!.call(
            address: "ExponentPushToken[bbbb2222]",
            verification: "verified",
          )
        end

        subject(:result) { for_channel.call("push") }

        it "is recipient_ready with eligible verified endpoint" do
          expect(result.recipient_ready).to be(true)
          expect(result.eligible_endpoint_ids).to eq([verified.id])
          expect(result.endpoint_count).to eq(2)
          expect(result.ready).to be(false) # platform_unconfigured fail-closed
          expect(result.reason_codes).to include("platform_unconfigured")
        end
      end

      context "when only revoked endpoints exist" do
        before { create_push!.call(address: "ExponentPushToken[aaaa1111]", lifecycle: "revoked") }

        subject(:result) { for_channel.call("push") }

        it "reports endpoint_inactive or endpoint_invalid" do
          expect(result.reason_codes).to include("endpoint_inactive").or include("endpoint_invalid")
        end
      end
    end

    context "pushover endpoints" do
      around do |example|
        previous = CommandTower.config.messaging.pushover.adapter
        CommandTower.config.messaging.pushover.adapter = "fake"
        example.run
      ensure
        CommandTower.config.messaging.pushover.adapter = previous
      end

      let(:create_verified_pushover!) do
        view = CommandTower::Messaging::Endpoints.create(
          owner_user_id: user.id,
          channel_key: "pushover",
          credentials: {
            user_key: "u" + ("a" * 30),
            application_token: "t" + ("b" * 30),
          },
        )
        record = CommandTower::Messaging::Endpoint.find(view.id)
        record.update!(verification_state: "verified", verified_at: Time.current)
        record
      end

      context "when an active verified endpoint exists and adapter is configured" do
        let!(:record) { create_verified_pushover! }

        subject(:result) { for_channel.call("pushover") }

        it "is ready with resolved_endpoint_id" do
          expect(result.recipient_ready).to be(true)
          expect(result.platform_configured).to be(true)
          expect(result.ready).to be(true)
          expect(result.eligible_endpoint_ids).to eq([record.id])
          expect(result.resolved_endpoint_id).to eq(record.id)
        end
      end

      context "when verified but typed credential child is absent" do
        before do
          record = create_verified_pushover!
          record.pushover_credential.destroy!
          record.reload
        end

        subject(:result) { for_channel.call("pushover") }

        it "reports credentials_missing" do
          expect(result.recipient_ready).to be(false)
          expect(result.ready).to be(false)
          expect(result.reason_codes).to include("credentials_missing")
          expect(result.resolved_endpoint_id).to be_nil
        end
      end

      context "when only active unverified pushover exists" do
        before do
          CommandTower::Messaging::Endpoints.create(
            owner_user_id: user.id,
            channel_key: "pushover",
            credentials: {
              user_key: "u" + ("a" * 30),
              application_token: "t" + ("b" * 30),
            },
          )
        end

        subject(:result) { for_channel.call("pushover") }

        it "reports endpoint_unverified" do
          expect(result.recipient_ready).to be(false)
          expect(result.reason_codes).to include("endpoint_unverified")
          expect(result.resolved_endpoint_id).to be_nil
        end
      end

      context "when adapter is disabled" do
        before do
          CommandTower.config.messaging.pushover.adapter = "disabled"
          create_verified_pushover!
        end

        subject(:result) { for_channel.call("pushover") }

        it "reports platform_unconfigured" do
          expect(result.recipient_ready).to be(true)
          expect(result.platform_configured).to be(false)
          expect(result.ready).to be(false)
          expect(result.reason_codes).to include("platform_unconfigured")
        end
      end

      context "when no pushover endpoint exists" do
        subject(:result) { for_channel.call("pushover") }

        it "reports endpoint_missing" do
          expect(result.recipient_ready).to be(false)
          expect(result.reason_codes).to include("endpoint_missing")
        end
      end

      context "when verifying secrets are not decrypted" do
        before { create_verified_pushover! }

        subject(:result) { for_channel.call("pushover") }

        it "does not decrypt secrets during readiness" do
          expect(CommandTower::Messaging::Endpoints::SecretReader).not_to receive(:read_pushover_credentials!)
          expect(CommandTower::Messaging::Endpoints::SecretReader).not_to receive(:read!)

          expect(result.ready).to be(true)
          expect(result.to_h.values.map(&:to_s).join).not_to include("aaaaaaaaaa")
        end
      end
    end
  end

  describe ".for_recipient" do
    before do
      allow(
        CommandTower::Messaging::Execution::Adapters::Email::Configuration,
      ).to receive(:email_configured?).and_return(true)
    end

    context "when summarizing all catalog channels" do
      subject(:result) { for_recipient.call }

      it "returns results for all catalog channels" do
        expect(result.channels.keys).to match_array(%w[inbox email sms push pushover])
        expect(result.channel("inbox").ready).to be(true)
        expect(result.channel("email").recipient_ready).to be(true)
        expect(result.recipient_ready_channel_keys).to include("inbox", "email")
      end
    end

    context "when a verified push endpoint exists" do
      before { create_push!.call(address: "ExponentPushToken[secret9999]", verification: "verified") }

      subject(:result) { for_recipient.call.channel("push") }

      it "does not leak secrets in channel results" do
        expect(result.members).not_to include(:address_ciphertext)
        expect(result.to_h.values.map(&:to_s).join).not_to include("secret9999")
      end
    end
  end

  describe CommandTower::Messaging::RecipientReadiness::IdentityFacts do
    context "when Identity phone columns are present" do
      subject(:facts) { described_class.for_user(user) }

      it "reports phone_supported" do
        expect(facts.phone_supported).to be(true)
        expect(facts.phone_present).to be(false)
        expect(facts.phone_number_validated).to be(false)
        expect(facts.email_supported).to be(true)
        expect(facts.email_present).to be(true)
        expect(facts.email_validated).to be(true)
      end
    end

    context "when phone is present but unverified" do
      before { user.update!(phone_number: "+14155552671", phone_number_validated: false) }

      subject(:facts) { described_class.for_user(user.reload) }

      it "reports phone_present and unverified from real columns" do
        expect(facts.phone_supported).to be(true)
        expect(facts.phone_present).to be(true)
        expect(facts.phone_number_validated).to be(false)
      end
    end
  end
end
