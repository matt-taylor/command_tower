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
    it "reports email, sms, and pushover as supported channels" do
      expect(described_class.supported_channel?("sms")).to eq(true)
      expect(described_class.supported_channel?("email")).to eq(true)
      expect(described_class.supported_channel?("pushover")).to eq(true)
      expect(described_class.supported_channel?("push")).to eq(false)
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
