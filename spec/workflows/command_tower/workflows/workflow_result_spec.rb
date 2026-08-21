# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::WorkflowResult do
  describe ".success" do
    subject(:result) { described_class.success(payload: { ok: true }, meta: { page: 1 }) }

    it { expect(result).to be_success }
    it { expect(result).not_to be_deferred }
    it { expect(result.reason).to be_nil }
    it { expect(result.retry_after).to be_nil }
    it { expect(result.payload).to eq(ok: true) }
    it { expect(result.errors).to eq([]) }
    it { expect(result.http_status).to eq(:ok) }
    it { expect(result.meta).to eq(page: 1) }
    it { expect(result.response_effects).to be_nil }
  end

  describe ".failure" do
    subject(:result) do
      described_class.failure(
        errors: [CommandTower::Errors::ValidationError.new],
        http_status: :unprocessable_entity
      )
    end

    it { expect(result).to be_failure }
    it { expect(result).not_to be_success }
    it { expect(result).not_to be_deferred }
    it { expect(result.payload).to be_nil }
    it { expect(result.http_status).to eq(:unprocessable_entity) }
    it { expect(result.errors.size).to eq(1) }
  end

  describe ".deferred" do
    subject(:result) do
      described_class.deferred(reason: :provider_cooldown, retry_after: 17, payload: { ok: false })
    end

    it { expect(result).to be_deferred }
    it { expect(result).not_to be_success }
    it { expect(result).not_to be_failure }
    it { expect(result.reason).to eq(:provider_cooldown) }
    it { expect(result.retry_after).to eq(17) }
    it { expect(result.http_status).to eq(:accepted) }
    it { expect(result.payload).to eq(ok: false) }
    it { expect(result.errors).to eq([]) }
  end
end
