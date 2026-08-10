# frozen_string_literal: true

RSpec.describe CommandTower::Clients::Transport::Request do
  describe ".build" do
    context "with normalized attributes" do
      subject(:request) do
        described_class.build(
          method: "POST",
          url: "https://example.test/v1/items",
          headers: { "Content-Type" => "application/json", Accept: "application/json" },
          body: '{"a":1}',
          query: { Page: 2 },
          timeout: 5
        )
      end

      it "normalizes method, headers, and query keys" do
        expect(request.method).to eq(:post)
        expect(request.url).to eq("https://example.test/v1/items")
        expect(request.headers).to eq(
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        )
        expect(request.query).to eq("Page" => 2)
        expect(request.body).to eq('{"a":1}')
        expect(request.timeout).to eq(5)
      end
    end

    context "with an unsupported HTTP method" do
      subject(:invoke) { described_class.build(method: :options, url: "https://example.test") }

      it "raises ConfigurationError" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::ConfigurationError,
          /unsupported HTTP method/
        )
      end
    end
  end

  describe "#merge_headers" do
    let(:request) do
      described_class.build(
        method: :get,
        url: "https://example.test",
        headers: { "X-A" => "1" }
      )
    end

    subject(:merged) { request.merge_headers("X-B" => "2") }

    it "returns a new request with merged headers" do
      expect(merged.headers).to eq("X-A" => "1", "X-B" => "2")
      expect(request.headers).to eq("X-A" => "1")
    end
  end
end
