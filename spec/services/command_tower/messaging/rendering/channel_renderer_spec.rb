# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Rendering::RenderedPayload do
  describe ".build" do
    subject(:payload) do
      described_class.build(
        recipient_address: "user@example.com",
        subject: "Subject",
        text_body: "Text",
        html_body: "<p>HTML</p>",
      )
    end

    it "builds a frozen payload of required strings" do
      expect(payload).to be_frozen
      expect(payload.subject).to eq("Subject")
    end
  end

  describe "validation" do
    it "rejects blank recipient_address" do
      expect {
        described_class.build(
          recipient_address: "",
          subject: "Subject",
          text_body: "Text",
          html_body: "<p>HTML</p>",
        )
      }.to raise_error(ArgumentError)
    end

    it "rejects hash recipient_address" do
      expect {
        described_class.build(
          recipient_address: { email: "user@example.com" },
          subject: "Subject",
          text_body: "Text",
          html_body: "<p>HTML</p>",
        )
      }.to raise_error(ArgumentError)
    end

    it "rejects exception html_body" do
      expect {
        described_class.build(
          recipient_address: "user@example.com",
          subject: "Subject",
          text_body: "Text",
          html_body: RuntimeError.new("boom"),
        )
      }.to raise_error(ArgumentError)
    end
  end
end

RSpec.describe CommandTower::Messaging::Rendering::RenderedSmsPayload do
  describe ".build" do
    subject(:payload) { described_class.build(recipient_address: "+14155552671", body: "Hello") }

    it "builds a frozen SMS payload" do
      expect(payload).to be_frozen
      expect(payload.body).to eq("Hello")
    end
  end

  it "rejects blank body" do
    expect { described_class.build(recipient_address: "+14155552671", body: "") }.to raise_error(ArgumentError)
  end
end

RSpec.describe CommandTower::Messaging::Rendering::RenderError do
  it "accepts only bounded safe codes" do
    expect(described_class.new(code: "recipient_missing").code).to eq("recipient_missing")
    expect(described_class.new(code: "render_failed", error_class: "ERB::Error")).to have_attributes(
      code: "render_failed",
      error_class: "ERB::Error",
    )
    expect { described_class.new(code: "adapter_unconfigured") }.to raise_error(ArgumentError)
  end
end

RSpec.describe CommandTower::Messaging::Rendering::ChannelRenderer, :messaging_accept do
  around do |example|
    previous_home = CommandTower.config.messaging.expo.home_deep_link
    example.run
  ensure
    CommandTower.config.messaging.expo.home_deep_link = previous_home
  end

  let(:user) { create(:user, email: "recipient@example.com") }
  let(:communication) do
    create(
      :messaging_communication,
      user:,
      title: "Hello <World>",
      body: "Body with <script>alert(1)</script>",
      metadata: nil,
    )
  end

  describe ".render" do
    context "for email with default communication" do
      subject(:payload) do
        described_class.render(
          communication:,
          channel_key: "email",
          recipient_address: user.email,
        )
      end

      it "renders email subject, text, and escaped HTML from supplied inputs" do
        expect(payload.recipient_address).to eq("recipient@example.com")
        expect(payload.subject).to eq("Hello <World>")
        expect(payload.text_body).to include("Hello <World>")
        expect(payload.text_body).to include("Body with <script>alert(1)</script>")
        expect(payload.html_body).to include("Hello &lt;World&gt;")
        expect(payload.html_body).to include("&lt;script&gt;alert(1)&lt;/script&gt;")
        expect(payload.html_body).not_to include("<script>")
      end
    end

    context "when metadata includes a deep_link" do
      before do
        communication.update!(metadata: { "deep_link" => "https://example.com/path" })
      end

      subject(:payload) do
        described_class.render(
          communication:,
          channel_key: "email",
          recipient_address: user.email,
        )
      end

      it "includes an optional deep_link footer when present in metadata" do
        expect(payload.text_body).to include("https://example.com/path")
        expect(payload.html_body).to include("https://example.com/path")
      end
    end

    context "when the host has not registered a config.email_theme override" do
      before do
        communication.update!(metadata: { "deep_link" => "https://example.com/path" })
      end

      subject(:payload) do
        described_class.render(
          communication:,
          channel_key: "email",
          recipient_address: user.email,
        )
      end

      it "renders the exact prior hardcoded colors unchanged (Slice 2.8 defaults match the old palette)" do # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
        expect(payload.html_body).to include("background-color: #f4f5f7")
        expect(payload.html_body).to include("background-color: #ffffff")
        expect(payload.html_body).to include("border: 1px solid #e2e8f0")
        expect(payload.html_body).to include("color: #1a202c")
        expect(payload.html_body).to include("color: #4a5568")
        expect(payload.html_body).to include("color: #2b6cb0")
      end
    end

    context "when a host has overridden config.email_theme" do
      around do |example|
        previous = CommandTower.config.email_theme.primary_action
        CommandTower.config.email_theme.primary_action = "#123456"
        example.run
      ensure
        CommandTower.config.email_theme.primary_action = previous
      end

      before do
        communication.update!(metadata: { "deep_link" => "https://example.com/path" })
      end

      subject(:payload) do
        described_class.render(
          communication:,
          channel_key: "email",
          recipient_address: user.email,
        )
      end

      it "renders the overridden theme value, proving the template reads the resolver live" do
        expect(payload.html_body).to include("color: #123456")
        expect(payload.html_body).not_to include("color: #2b6cb0")
      end
    end

    context "for SMS with reservation metadata" do
      before do
        communication.update!(
          title: "Reservation",
          body: "Your reservation was confirmed.",
          metadata: { "deep_link" => "https://example.com/r/1" },
        )
      end

      subject(:payload) do
        described_class.render(
          communication:,
          channel_key: "sms",
          recipient_address: "+14155552671",
        )
      end

      it "renders SMS body as a provider-neutral RenderedSmsPayload without truncation" do
        expect(payload).to be_a(CommandTower::Messaging::Rendering::RenderedSmsPayload)
        expect(payload.recipient_address).to eq("+14155552671")
        expect(payload.body).to include("Reservation")
        expect(payload.body).to include("Your reservation was confirmed.")
        expect(payload.body).to include("https://example.com/r/1")
        expect(payload).not_to respond_to(:html_body)
      end
    end

    context "for Pushover with reservation metadata" do
      before do
        communication.update!(
          title: "Reservation",
          body: "Your reservation was confirmed.",
          metadata: { "deep_link" => "https://example.com/r/1" },
        )
      end

      subject(:payload) do
        described_class.render(
          communication:,
          channel_key: "pushover",
          recipient_address: "42",
        )
      end

      it "renders Pushover as a typed payload with opaque endpoint id and no credentials" do
        expect(payload).to be_a(CommandTower::Messaging::Rendering::RenderedPushoverPayload)
        expect(payload).to be_frozen
        expect(payload.recipient_address).to eq("42")
        expect(payload.title).to eq("Reservation")
        expect(payload.message).to include("Your reservation was confirmed.")
        expect(payload.message).to include("https://example.com/r/1")
        expect(payload.to_h.values.map(&:to_s).join).not_to match(/user_key|application_token/i)
      end
    end

    context "for push with deep_link metadata" do
      before do
        communication.update!(
          title: "Announcement",
          body: "Season opens tonight.",
          metadata: { "deep_link" => "pickem://announcements/1" },
        )
      end

      subject(:payload) do
        described_class.render(
          communication:,
          channel_key: "push",
          recipient_address: "99",
        )
      end

      it "renders push title, body, and optional deep_link without embedding the token" do
        expect(payload).to be_a(CommandTower::Messaging::Rendering::RenderedPushPayload)
        expect(payload).to be_frozen
        expect(payload.recipient_address).to eq("99")
        expect(payload.title).to eq("Announcement")
        expect(payload.body).to eq("Season opens tonight.")
        expect(payload.deep_link).to eq("pickem://announcements/1")
      end
    end

    context "for push presentation" do
      subject(:payload) do
        described_class.render(communication:, channel_key: "push", recipient_address: "99")
      end

      before { communication.update!(title: "Hi", body: "Body", metadata: { "deep_link" => "pickem://x" }) }

      it "renders the default presentation for an unregistered type and records one fallback" do
        expect(CommandTower::Messaging::Execution::OperationLogger).to receive(:push_presentation_fallback)
          .with(communication:, reason_code: "type_unregistered", channel_delivery: nil)

        expect(payload).to have_attributes(sound: nil, urgency: "normal", thread_id: nil, badge: nil)
      end

      context "with a registered type and a conversation" do
        let(:host_sounds) { [{ id: "chime", label: "Chime", asset: "chime.wav" }] }
        let(:badge_eligible) { false }

        around do |example|
          previous = CommandTower.config.messaging.sounds
          example.run
        ensure
          CommandTower.config.messaging.sounds = previous
          CommandTower::Messaging::NotificationTypes.reset!
        end

        before do
          CommandTower.config.messaging.sounds = host_sounds
          CommandTower::Messaging::NotificationTypes.reset!
          CommandTower::Messaging::NotificationTypes.register(
            CommandTower::Messaging::NotificationTypes::Declaration.build(
              key: communication.notification_type_key,
              allowed_channels: %w[push],
              default_channels: %w[push],
              inbox_available: true,
              user_configurable: true,
              mandatory: false,
              default_preference_state: { "channels" => { "push" => true }, "inbox" => true },
              label: "Example",
              category_key: "example",
              category_label: "Example",
              category_order: 1,
              type_order: 1,
              urgency: { default: "normal", allowed: %w[normal time_sensitive] },
              sound: { default: "default", allowed: %w[default chime] },
              badge_eligible:,
            ),
          )
          CommandTower::Messaging::NotificationTypes.seal
          create(
            :messaging_notification_preference,
            user:,
            notification_type_key: communication.notification_type_key,
            state: { "channels" => {}, "inbox" => true, "urgency" => "time_sensitive", "sound" => "chime" },
          )
          communication.update!(conversation_key: "league.1.period.2", conversation_title: "Friends · Week 2")
        end

        it "carries the effective sound, urgency, and conversation thread" do
          expect(payload).to have_attributes(
            sound: "chime.wav",
            urgency: "time_sensitive",
            thread_id: "league.1.period.2",
            deep_link: "pickem://x",
            badge: nil,
          )
        end

        context "when the type is badge eligible and has an unread inbox item" do
          let(:badge_eligible) { true }

          before { create(:messaging_inbox_item, communication:) }

          it "carries the eligible unread count and the same deep link" do
            expect(payload).to have_attributes(badge: 1, deep_link: "pickem://x")
          end
        end

        it "does not add presentation to email, SMS, or Pushover renders" do
          expect(CommandTower::Messaging::Rendering::PushPresentation).not_to receive(:call)

          described_class.render(communication:, channel_key: "email", recipient_address: "a@example.com")
        end
      end
    end

    context "for push with deep_link metadata when Home is a callable" do
      let(:home_calls) { [] }

      before do
        communication.update!(
          title: "Announcement",
          body: "Season opens tonight.",
          metadata: { "deep_link" => "pickem://announcements/1" },
        )
        CommandTower.config.messaging.expo.home_deep_link = lambda {
          home_calls << true
          "pickem://home"
        }
      end

      subject(:payload) do
        described_class.render(
          communication:,
          channel_key: "push",
          recipient_address: "99",
        )
      end

      it "keeps the metadata deep link and does not call Home" do
        expect(payload.deep_link).to eq("pickem://announcements/1")
        expect(home_calls).to be_empty
      end
    end

    context "for push without deep_link and a live inbox item" do
      before do
        communication.update!(title: "Hi", body: "Body only", metadata: nil)
        create(:messaging_inbox_item, communication:)
      end

      subject(:payload) do
        described_class.render(
          communication:,
          channel_key: "push",
          recipient_address: "7",
        )
      end

      it "renders a nil deep_link when a live inbox item is the destination" do
        expect(CommandTower::Messaging::Execution::OperationLogger).not_to receive(:push_destination_fallback)
        expect(payload.deep_link).to be_nil
        expect(payload.body).to eq("Body only")
      end
    end

    context "for push without deep_link and an archived inbox item" do
      before do
        communication.update!(title: "Hi", body: "Still there", metadata: nil)
        create(:messaging_inbox_item, :archived, communication:)
      end

      subject(:payload) do
        described_class.render(
          communication:,
          channel_key: "push",
          recipient_address: "7",
        )
      end

      it "treats an archived item as a live destination" do
        expect(CommandTower::Messaging::Execution::OperationLogger).not_to receive(:push_destination_fallback)
        expect(payload.deep_link).to be_nil
      end
    end

    context "for push with a deep link and a live inbox item" do
      before do
        communication.update!(
          title: "Both",
          body: "Link and inbox",
          metadata: { "deep_link" => "pickem://announcements/2" },
        )
        create(:messaging_inbox_item, communication:)
      end

      subject(:payload) do
        described_class.render(
          communication:,
          channel_key: "push",
          recipient_address: "7",
        )
      end

      it "keeps the metadata deep link" do
        expect(payload.deep_link).to eq("pickem://announcements/2")
      end
    end

    context "for a destinationless push" do
      before do
        communication.update!(title: "Hi", body: "Nowhere", metadata: nil)
        CommandTower.config.messaging.expo.home_deep_link = "pickem://home"
      end

      subject(:payload) do
        described_class.render(
          communication:,
          channel_key: "push",
          recipient_address: "7",
        )
      end

      it "substitutes Home and logs destination_missing without creating an inbox item" do
        expect(CommandTower::Messaging::Execution::OperationLogger).to receive(:push_destination_fallback).with(
          communication:,
          reason_code: "destination_missing",
          level: :error,
          channel_delivery: nil,
        )

        expect { payload.deep_link }.not_to change(CommandTower::Messaging::InboxItem, :count)
        expect(payload.deep_link).to eq("pickem://home")
      end
    end

    context "for a destinationless push when inbox was turned off" do
      before do
        communication.update!(title: "Hi", body: "Inbox off", metadata: nil)
        create(
          :messaging_destination_plan,
          communication:,
          decision: {
            "selected_channels" => %w[push],
            "inbox_selected" => false,
            "mandatory" => false,
            "platform_enabled_channels" => %w[push],
            "excluded_destinations" => [
              { "destination" => "inbox", "reason_class" => "suppressed_by_preference" },
            ],
          },
        )
        CommandTower.config.messaging.expo.home_deep_link = "pickem://home"
      end

      subject(:payload) do
        described_class.render(
          communication:,
          channel_key: "push",
          recipient_address: "7",
        )
      end

      it "substitutes Home and logs inbox_disabled at info" do
        expect(CommandTower::Messaging::Execution::OperationLogger).to receive(:push_destination_fallback).with(
          communication:,
          reason_code: "inbox_disabled",
          level: :info,
          channel_delivery: nil,
        )
        expect(payload.deep_link).to eq("pickem://home")
        expect(communication.reload.inbox_item).to be_nil
      end
    end

    context "for a destinationless push excluded by policy" do
      before do
        communication.update!(title: "Hi", body: "Policy", metadata: nil)
        create(
          :messaging_destination_plan,
          communication:,
          decision: {
            "selected_channels" => %w[push],
            "inbox_selected" => false,
            "mandatory" => false,
            "platform_enabled_channels" => %w[push],
            "excluded_destinations" => [
              { "destination" => "inbox", "reason_class" => "skipped_by_policy" },
            ],
          },
        )
        CommandTower.config.messaging.expo.home_deep_link = "pickem://home"
      end

      subject(:payload) do
        described_class.render(
          communication:,
          channel_key: "push",
          recipient_address: "7",
        )
      end

      it "substitutes Home and logs destination_missing" do
        expect(CommandTower::Messaging::Execution::OperationLogger).to receive(:push_destination_fallback).with(
          communication:,
          reason_code: "destination_missing",
          level: :error,
          channel_delivery: nil,
        )
        expect(payload.deep_link).to eq("pickem://home")
      end
    end

    context "for a destinationless push whose inbox item was deleted" do
      before do
        communication.update!(title: "Hi", body: "Deleted", metadata: nil)
        create(:messaging_inbox_item, :deleted, communication:)
        CommandTower.config.messaging.expo.home_deep_link = "pickem://home"
      end

      subject(:payload) do
        described_class.render(
          communication:,
          channel_key: "push",
          recipient_address: "7",
        )
      end

      it "substitutes Home and logs destination_missing" do
        expect(CommandTower::Messaging::Execution::OperationLogger).to receive(:push_destination_fallback).with(
          communication:,
          reason_code: "destination_missing",
          level: :error,
          channel_delivery: nil,
        )
        expect(payload.deep_link).to eq("pickem://home")
      end
    end

    context "for a destinationless push when Home cannot be resolved" do
      before do
        communication.update!(title: "Hi", body: "No home", metadata: nil)
        CommandTower.config.messaging.expo.home_deep_link = lambda { " " }
      end

      subject(:payload) do
        described_class.render(
          communication:,
          channel_key: "push",
          recipient_address: "7",
        )
      end

      it "fails terminally and does not invent a link" do
        expect(CommandTower::Messaging::Execution::OperationLogger).to receive(:push_destination_fallback).with(
          communication:,
          reason_code: "home_deep_link_unresolved",
          level: :error,
          channel_delivery: nil,
        )

        expect { payload }.to raise_error(CommandTower::Messaging::Rendering::RenderError) { |error|
          expect(error.code).to eq("render_failed")
          expect(error.error_class).to eq("HomeDeepLinkUnresolved")
        }
      end
    end

    context "when recipient address is blank" do
      it "raises recipient_missing for blank recipient addresses without querying User" do
        expect(User).not_to receive(:find)
        expect(User).not_to receive(:find_by)

        expect do
          described_class.render(
            communication:,
            channel_key: "email",
            recipient_address: "   ",
          )
        end.to raise_error(CommandTower::Messaging::Rendering::RenderError) { |error|
          expect(error.code).to eq("recipient_missing")
        }
      end
    end

    context "when render_template raises an unexpected error" do
      let(:instance) do
        described_class.new(
          communication:,
          channel_key: "email",
          recipient_address: user.email,
        )
      end

      before do
        allow(instance).to receive(:render_template).and_raise(Errno::ENOENT, "missing")
        allow(described_class).to receive(:new).and_return(instance)
      end

      it "raises render_failed when templates cannot be rendered" do
        expect do
          described_class.render(
            communication:,
            channel_key: "email",
            recipient_address: user.email,
          )
        end.to raise_error(CommandTower::Messaging::Rendering::RenderError) { |error|
          expect(error.code).to eq("render_failed")
          expect(error.error_class).to eq("Errno::ENOENT")
        }
      end
    end

    context "when communication title is blank" do
      before do
        allow(communication).to receive(:title).and_return("")
        allow(communication).to receive(:body).and_return("Body only")
      end

      subject(:payload) do
        described_class.render(
          communication:,
          channel_key: "pushover",
          recipient_address: "7",
        )
      end

      it "falls back to a default Pushover title when communication title is blank" do
        expect(payload.title).to eq("Body only")
      end
    end

    context "when communication title and body are both blank" do
      before do
        allow(communication).to receive(:title).and_return("T")
        allow(communication).to receive(:body).and_return("")
      end

      it "rejects empty Pushover message bodies" do
        expect do
          described_class.render(
            communication:,
            channel_key: "pushover",
            recipient_address: "7",
          )
        end.to raise_error(CommandTower::Messaging::Rendering::RenderError) { |error|
          expect(error.code).to eq("render_failed")
        }
      end
    end
  end

  describe ".supported_channel?" do
    it "reports email, sms, pushover, and push as supported channels" do
      expect(described_class.supported_channel?("sms")).to eq(true)
      expect(described_class.supported_channel?("email")).to eq(true)
      expect(described_class.supported_channel?("pushover")).to eq(true)
      expect(described_class.supported_channel?("push")).to eq(true)
      expect(described_class.supported_channel?("fax")).to eq(false)
    end
  end

  describe ".render", :messaging_rich_messaging_proof do
    context "when the notification_type_key has a matching template directory" do
      let(:communication_with_type) do
        create(
          :messaging_communication,
          user:,
          notification_type_key: "rich_messaging_proof",
          title: "Type Override",
          body: "Type body",
          metadata: nil,
        )
      end

      subject(:email_payload) do
        described_class.render(
          communication: communication_with_type,
          channel_key: "email",
          recipient_address: user.email,
        )
      end

      it "renders the type-specific email HTML override" do
        expect(email_payload.html_body).to include("PROOF OVERRIDE: Type Override")
      end

      it "still renders email text from the generic template for the same communication" do
        expect(email_payload.text_body).not_to include("PROOF OVERRIDE")
        expect(email_payload.text_body).to include("Type Override")
      end
    end

    context "when the type directory exists but is missing a basename" do
      let(:communication_with_type) do
        create(
          :messaging_communication,
          user:,
          notification_type_key: "rich_messaging_proof",
          title: "Partial Type",
          body: "Partial body",
          metadata: nil,
        )
      end

      before { create(:messaging_inbox_item, communication: communication_with_type) }

      subject(:push_payload) do
        described_class.render(
          communication: communication_with_type,
          channel_key: "push",
          recipient_address: "7",
        )
      end

      it "falls back to the generic template for the missing basename only" do
        expect(push_payload.body).to include("Partial body")
        expect(push_payload.body).not_to include("PROOF OVERRIDE")
      end
    end

    context "when the notification_type_key has no matching template directory" do
      let(:communication_without_type_dir) do
        create(
          :messaging_communication,
          user:,
          notification_type_key: "rich_messaging_unregistered",
          title: "No Type Dir",
          body: "Generic body",
          metadata: nil,
        )
      end

      subject(:email_payload) do
        described_class.render(
          communication: communication_without_type_dir,
          channel_key: "email",
          recipient_address: user.email,
        )
      end

      it "renders the generic template for every destination" do
        expect(email_payload.html_body).not_to include("PROOF OVERRIDE")
        expect(email_payload.html_body).to include("No Type Dir")
      end
    end

    context "when the notification_type_key fails the sanitized-key pattern" do
      let(:dotted_communication) do
        create(
          :messaging_communication,
          user:,
          notification_type_key: "example.type",
          title: "Dotted Key",
          body: "Dotted body",
          metadata: nil,
        )
      end

      subject(:email_payload) do
        described_class.render(
          communication: dotted_communication,
          channel_key: "email",
          recipient_address: user.email,
        )
      end

      it "never attempts the matching-but-unsanitized type directory" do
        expect(email_payload.html_body).not_to include("SHOULD NOT RENDER")
        expect(email_payload.html_body).to include("Dotted Key")
      end
    end

    context "when the type-specific template raises mid-render" do
      let(:malformed_communication) do
        create(
          :messaging_communication,
          user:,
          notification_type_key: "rich_messaging_malformed",
          title: "Malformed",
          body: "Malformed body",
          metadata: nil,
        )
      end

      subject(:render_call) do
        described_class.render(
          communication: malformed_communication,
          channel_key: "email",
          recipient_address: user.email,
        )
      end

      it "surfaces render_failed with the original error class, matching a missing-template failure" do
        expect { render_call }.to raise_error(CommandTower::Messaging::Rendering::RenderError) { |error|
          expect(error.code).to eq("render_failed")
          expect(error.error_class).to eq("NameError")
        }
      end
    end

    context "when a host fixture view path overrides the engine's generic template" do
      subject(:sms_payload) do
        described_class.render(
          communication:,
          channel_key: "sms",
          recipient_address: "+14155552671",
        )
      end

      it "renders the host-fixture template ahead of the engine default" do
        expect(sms_payload.body).to start_with("HOST OVERRIDE:")
      end
    end
  end
end

RSpec.describe CommandTower::Messaging::Rendering::RenderedPushoverPayload do
  describe ".build" do
    subject(:payload) do
      described_class.build(
        recipient_address: "99",
        title: "Hello",
        message: "World",
      )
    end

    it "builds a frozen Pushover payload" do
      expect(payload).to be_frozen
      expect(payload.message).to eq("World")
    end
  end

  it "rejects blank message" do
    expect { described_class.build(recipient_address: "99", title: "Hello", message: "") }.to raise_error(ArgumentError)
  end
end
