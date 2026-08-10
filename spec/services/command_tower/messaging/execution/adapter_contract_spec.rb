# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Execution::AdapterRequest do
  let(:build_rendered) do
    CommandTower::Messaging::Rendering::RenderedPayload.build(
      recipient_address: "user@example.com",
      subject: "Hello",
      text_body: "Plain text",
      html_body: "<p>HTML</p>",
    )
  end

  context "with valid attributes" do
    subject(:request) do
      described_class.build(
        channel_delivery_id: 1,
        communication_id: 2,
        channel_key: "email",
        attempt_id: 3,
        rendered: build_rendered,
      )
    end

    it "builds an immutable request with a rendered payload" do
      expect(request).to be_frozen
      expect(request.channel_key).to eq("email")
      expect(request.rendered.recipient_address).to eq("user@example.com")
    end
  end

  context "with a blank channel key" do
    subject(:invoke) do
      described_class.build(
        channel_delivery_id: 1,
        communication_id: 2,
        channel_key: "",
        attempt_id: 3,
        rendered: build_rendered,
      )
    end

    it "raises InvalidAdapterContractError" do
      expect { invoke }.to raise_error(CommandTower::Messaging::Execution::InvalidAdapterContractError)
    end
  end

  context "with a non-string channel key" do
    subject(:invoke) do
      described_class.build(
        channel_delivery_id: 1,
        communication_id: 2,
        channel_key: :email,
        attempt_id: 3,
        rendered: build_rendered,
      )
    end

    it "raises InvalidAdapterContractError" do
      expect { invoke }.to raise_error(CommandTower::Messaging::Execution::InvalidAdapterContractError)
    end
  end

  context "with a nil rendered payload" do
    subject(:invoke) do
      described_class.build(
        channel_delivery_id: 1,
        communication_id: 2,
        channel_key: "email",
        attempt_id: 3,
        rendered: nil,
      )
    end

    it "raises InvalidAdapterContractError" do
      expect { invoke }.to raise_error(CommandTower::Messaging::Execution::InvalidAdapterContractError)
    end
  end

  context "with an invalid rendered payload type" do
    subject(:invoke) do
      described_class.build(
        channel_delivery_id: 1,
        communication_id: 2,
        channel_key: "email",
        attempt_id: 3,
        rendered: { recipient_address: "a@b.c", subject: "s", text_body: "t", html_body: "h" },
      )
    end

    it "raises InvalidAdapterContractError" do
      expect { invoke }.to raise_error(CommandTower::Messaging::Execution::InvalidAdapterContractError)
    end
  end
end

RSpec.describe CommandTower::Messaging::Execution::AdapterResult do
  context "with supported outcomes" do
    it "accepts success" do
      expect(described_class.build(outcome: :success).outcome).to eq(:success)
    end

    it "accepts retryable_failure as a string" do
      expect(described_class.build(outcome: "retryable_failure").outcome).to eq(:retryable_failure)
    end

    it "accepts terminal_failure" do
      expect(described_class.build(outcome: :terminal_failure).outcome).to eq(:terminal_failure)
    end
  end

  context "with an unsupported outcome" do
    subject(:invoke) { described_class.build(outcome: :delivered) }

    it "raises InvalidAdapterContractError" do
      expect { invoke }.to raise_error(CommandTower::Messaging::Execution::InvalidAdapterContractError)
    end
  end

  context "with a non-symbol/string outcome" do
    subject(:invoke) { described_class.build(outcome: { ok: true }) }

    it "raises InvalidAdapterContractError" do
      expect { invoke }.to raise_error(CommandTower::Messaging::Execution::InvalidAdapterContractError)
    end
  end

  context "with an invalid error_code type" do
    subject(:invoke) { described_class.build(outcome: :success, error_code: RuntimeError.new("boom")) }

    it "raises InvalidAdapterContractError" do
      expect { invoke }.to raise_error(CommandTower::Messaging::Execution::InvalidAdapterContractError)
    end
  end

  context "with a multiline error_code" do
    subject(:invoke) do
      described_class.build(outcome: :success, error_code: "boom\n/app/foo.rb:1:in `call'")
    end

    it "raises InvalidAdapterContractError" do
      expect { invoke }.to raise_error(CommandTower::Messaging::Execution::InvalidAdapterContractError)
    end
  end

  context "with a non-string provider_message_id" do
    subject(:invoke) { described_class.build(outcome: :success, provider_message_id: 123) }

    it "raises InvalidAdapterContractError" do
      expect { invoke }.to raise_error(CommandTower::Messaging::Execution::InvalidAdapterContractError)
    end
  end
end
