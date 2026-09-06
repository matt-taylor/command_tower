# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Execution::Adapters::Expo::HttpClient do
  let(:configuration) do
    instance_double(
      CommandTower::Messaging::Execution::Adapters::Expo::Configuration,
      api_base_url: "https://exp.host/--/api/v2/push",
      timeout_seconds: 5,
      access_token: token,
    )
  end
  let(:token) { "" }
  let(:client) { described_class.new(configuration:) }
  let(:base) { "https://exp.host/--/api/v2/push" }

  describe "#send_messages" do
    let(:messages) do
      [{ "to" => "ExponentPushToken[abc]", "title" => "T", "body" => "B" }]
    end

    context "when Expo accepts the batch" do
      before do
        stub_request(:post, "#{base}/send")
          .to_return(
            status: 200,
            body: {
              data: [{ status: "ok", id: "ticket-1" }],
            }.to_json,
            headers: { "Content-Type" => "application/json" },
          )
      end

      subject(:result) { client.send_messages(messages) }

      it "posts the message array and returns normalized tickets" do
        expect(result[:ok]).to be(true)
        expect(result[:tickets]).to eq([
          { status: "ok", id: "ticket-1", message: nil, error: nil },
        ])
        expect(WebMock).to have_requested(:post, "#{base}/send")
          .with { |req| JSON.parse(req.body).is_a?(Array) && !req.headers.key?("Authorization") }
      end
    end

    context "when access_token is configured" do
      let(:token) { "secret-access" }

      before do
        stub_request(:post, "#{base}/send")
          .with(headers: { "Authorization" => "Bearer secret-access" })
          .to_return(
            status: 200,
            body: { data: [{ status: "ok", id: "t1" }] }.to_json,
            headers: { "Content-Type" => "application/json" },
          )
      end

      subject(:result) { client.send_messages(messages) }

      it "sends Authorization Bearer only when token is present" do
        expect(result[:ok]).to be(true)
        expect(WebMock).to have_requested(:post, "#{base}/send")
          .with(headers: { "Authorization" => "Bearer secret-access" })
      end
    end
  end

  describe "#get_receipts" do
    before do
      stub_request(:post, "#{base}/getReceipts")
        .to_return(
          status: 200,
          body: {
            data: {
              "ticket-1" => { status: "ok" },
              "ticket-2" => {
                status: "error",
                message: "gone",
                details: { error: "DeviceNotRegistered" },
              },
            },
          }.to_json,
          headers: { "Content-Type" => "application/json" },
        )
    end

    subject(:result) { client.get_receipts(%w[ticket-1 ticket-2]) }

    it "posts ticket ids and normalizes receipt statuses" do
      expect(result[:ok]).to be(true)
      expect(result[:receipts]["ticket-1"]).to eq(status: "ok", message: nil, error: nil)
      expect(result[:receipts]["ticket-2"][:error]).to eq("DeviceNotRegistered")
    end
  end
end
