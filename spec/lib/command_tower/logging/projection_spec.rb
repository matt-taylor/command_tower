# frozen_string_literal: true

RSpec.describe CommandTower::Logging::Projection do
  let(:event_name) { CommandTower::Events::WORKFLOW_COMPLETED }
  let(:payload) do
    {
      execution_uuid: "exec-1",
      correlation_id: "corr-1",
      request_id: "corr-1",
      causation_id: nil,
      source: :http,
      user_id: 1,
      originating_administrator_id: nil,
      effective_user_id: 1,
      impersonation_active: false,
      event_uuid: "evt-1",
      subject: "SomeWorkflow",
      layer: :workflow,
      outcome: :success,
      duration_ms: 10.21,
      log_lifecycle: true,
      log_level: :info
    }
  end
  let(:event) do
    ActiveSupport::Notifications::Event.new(event_name, Time.utc(2026, 1, 1), Time.utc(2026, 1, 1), "1", payload)
  end

  subject(:projected) { described_class.call(event) }

  it "projects core operational fields without subscriber metadata" do
    expect(projected).to eq(
      event: event_name,
      subject: "SomeWorkflow",
      execution_uuid: "exec-1",
      correlation_id: "corr-1",
      outcome: :success,
      duration_ms: 10.21,
      user_id: 1
    )
  end

  it "does not mutate the ASN payload" do
    described_class.call(event)
    expect(event.payload).to include(
      event_uuid: "evt-1",
      layer: :workflow,
      log_lifecycle: true,
      log_level: :info,
      causation_id: nil,
      impersonation_active: false,
      request_id: "corr-1",
      effective_user_id: 1,
      source: :http
    )
  end

  context "when request_id differs from correlation_id" do
    let(:payload) { super().merge(request_id: "req-9") }

    it { expect(projected[:request_id]).to eq("req-9") }
  end

  context "when source is a job" do
    let(:payload) { super().merge(source: :job) }

    it { expect(projected[:source]).to eq(:job) }
  end

  context "when source is rake" do
    let(:payload) { super().merge(source: :rake) }

    it { expect(projected[:source]).to eq(:rake) }
  end

  context "when source is console" do
    let(:payload) { super().merge(source: :console) }

    it { expect(projected[:source]).to eq(:console) }
  end

  context "when causation_id is present" do
    let(:payload) { super().merge(causation_id: "cause-1") }

    it { expect(projected[:causation_id]).to eq("cause-1") }
  end

  context "when originating_administrator_id is present" do
    let(:payload) { super().merge(originating_administrator_id: 7) }

    it { expect(projected[:originating_administrator_id]).to eq(7) }
  end

  context "when effective_user_id differs from user_id" do
    let(:payload) { super().merge(effective_user_id: 42, user_id: 7, impersonation_active: true, originating_administrator_id: 7) }

    it "includes impersonation identity fields" do
      expect(projected).to include(
        user_id: 7,
        effective_user_id: 42,
        originating_administrator_id: 7,
        impersonation_active: true
      )
    end
  end

  context "when the workflow errors" do
    let(:payload) { super().merge(outcome: :error, error_class: "StandardError", error_codes: ["internal"]) }

    it "keeps safe error scalars" do
      expect(projected).to include(outcome: :error, error_class: "StandardError", error_codes: ["internal"])
      expect(projected).not_to have_key(:log_level)
    end
  end

  context "when a semantic messaging event includes operational fields" do
    let(:event_name) { "command_tower.messaging.delivery_failed" }
    let(:payload) do
      {
        execution_uuid: "exec-1",
        correlation_id: "corr-1",
        source: :http,
        event_uuid: "evt-1",
        channel: :sms,
        provider: :twilio,
        attempt: 2,
        log_level: :error
      }
    end

    it "keeps event-specific fields and drops subscriber metadata" do
      expect(projected).to include(event: event_name, channel: :sms, provider: :twilio, attempt: 2)
      expect(projected).not_to have_key(:log_level)
      expect(projected).not_to have_key(:event_uuid)
      expect(projected).not_to have_key(:source)
    end
  end

  context "when an explicit log event includes a message" do
    let(:event_name) { "command_tower.log.warn" }
    let(:payload) do
      {
        execution_uuid: "exec-1",
        correlation_id: "corr-1",
        source: :http,
        event_uuid: "evt-1",
        message: "token mismatch",
        token_kind: "csrf"
      }
    end

    it "keeps the message and extra operational scalars" do
      expect(projected).to include(event: event_name, message: "token mismatch", token_kind: "csrf")
      expect(projected).not_to have_key(:event_uuid)
    end
  end

  context "when user_id is absent" do
    let(:payload) { super().except(:user_id).merge(effective_user_id: nil) }

    it { expect(projected).not_to have_key(:user_id) }
  end
end
