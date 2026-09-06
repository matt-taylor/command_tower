# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Execution::AdapterRequest do
  let(:rendered_email) do
    CommandTower::Messaging::Rendering::RenderedPayload.build(
      recipient_address: "a@example.com",
      subject: "S",
      text_body: "text",
      html_body: "<p>html</p>",
    )
  end

  let(:rendered_push) do
    CommandTower::Messaging::Rendering::RenderedPushPayload.build(
      recipient_address: "9",
      title: "T",
      body: "B",
    )
  end

  describe ".build" do
    context "with an email payload and default eligible_endpoint_ids" do
      subject(:request) do
        described_class.build(
          channel_delivery_id: 1,
          communication_id: 2,
          channel_key: "email",
          attempt_id: 3,
          rendered: rendered_email,
        )
      end

      it "freezes the request with an empty eligible_endpoint_ids list" do
        expect(request).to be_frozen
        expect(request.eligible_endpoint_ids).to eq([])
      end
    end

    context "with a push payload and eligible endpoint ids" do
      subject(:request) do
        described_class.build(
          channel_delivery_id: 1,
          communication_id: 2,
          channel_key: "push",
          attempt_id: 3,
          rendered: rendered_push,
          eligible_endpoint_ids: [10, "11"],
        )
      end

      it "accepts RenderedPushPayload and freezes integer endpoint ids" do
        expect(request.rendered).to eq(rendered_push)
        expect(request.eligible_endpoint_ids).to eq([10, 11])
        expect(request.eligible_endpoint_ids).to be_frozen
      end
    end

    context "when eligible_endpoint_ids contains a non-integer" do
      subject(:invoke) do
        described_class.build(
          channel_delivery_id: 1,
          communication_id: 2,
          channel_key: "push",
          attempt_id: 3,
          rendered: rendered_push,
          eligible_endpoint_ids: ["abc"],
        )
      end

      it "rejects non-integer eligible_endpoint_ids" do
        expect { invoke }.to raise_error(
          CommandTower::Messaging::Execution::InvalidAdapterContractError,
          /Integers/,
        )
      end
    end
  end
end
