# frozen_string_literal: true

RSpec.describe CommandTower::Clients::ClientResult do
  describe ".success" do
    subject(:result) do
      described_class.success(
        output: response,
        metadata: { status: 200, duration_ms: 3 }
      )
    end

    let(:response) do
      CommandTower::Clients::Transport::Response.build(status: 200, body: { ok: true })
    end

    it { is_expected.to be_success }
    it { is_expected.not_to be_failure }

    it "exposes output, metadata, and empty provider_metadata by default" do
      expect(result.output).to eq(response)
      expect(result.metadata).to eq(status: 200, duration_ms: 3)
      expect(result.provider_metadata).to eq({})
    end

    it "has no error" do
      expect(result.error).to be_nil
    end

    context "with provider_metadata" do
      subject(:result) do
        described_class.success(
          output: "ok",
          metadata: { status: 200 },
          provider_metadata: { pagination: :meta }
        )
      end

      it { expect(result.provider_metadata).to eq(pagination: :meta) }
    end
  end

  describe ".failure" do
    subject(:result) do
      described_class.failure(
        error: CommandTower::Clients::Errors::UpstreamError.new(message: "boom"),
        output: response,
        metadata: { status: 502 }
      )
    end

    let(:response) do
      CommandTower::Clients::Transport::Response.build(status: 502, body: "bad gateway")
    end

    it { is_expected.to be_failure }
    it { is_expected.not_to be_success }

    it "exposes singular error, optional output, and metadata" do
      expect(result.error).to be_a(CommandTower::Clients::Errors::UpstreamError)
      expect(result.error.message).to eq("boom")
      expect(result.output).to eq(response)
      expect(result.metadata).to eq(status: 502)
      expect(result.provider_metadata).to eq({})
    end

    context "with provider_metadata" do
      subject(:result) do
        described_class.failure(
          error: CommandTower::Clients::Errors::UpstreamError.new(message: "boom"),
          provider_metadata: { pagination: :meta }
        )
      end

      it { expect(result.provider_metadata).to eq(pagination: :meta) }
    end
  end
end
