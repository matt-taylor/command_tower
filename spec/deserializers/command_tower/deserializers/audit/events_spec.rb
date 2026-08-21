# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Audit::Events::UserListDeserializer do
  context "with an empty query" do
    subject(:result) { described_class.call({}) }

    it { expect(result).to be_success }

    it "uses inbox-compatible defaults" do
      expect(result.input).to have_attributes(
        limit: 50,
        offset: 0,
        actions: [],
        occurred_after: nil,
        occurred_before: nil,
        subject_types: []
      )
    end
  end

  context "with camelCase filters" do
    subject(:result) do
      described_class.call(
        "eventName" => "phone_updated",
        "occurredAfter" => "2026-08-16T12:00:00Z",
        "limit" => "10"
      )
    end

    it { expect(result).to be_success }

    it "coerces singular eventName into actions" do
      expect(result.input.actions).to eq(["phone_updated"])
      expect(result.input.occurred_after).to eq(Time.iso8601("2026-08-16T12:00:00Z"))
      expect(result.input.limit).to eq(10)
    end
  end

  context "with eventNames array" do
    subject(:result) do
      described_class.call("eventNames" => %w[session_created login_failed phone_updated])
    end

    it { expect(result).to be_success }

    it "accepts multi-value event names" do
      expect(result.input.actions).to eq(%w[session_created login_failed phone_updated])
    end
  end

  context "with subjectType" do
    subject(:result) { described_class.call("subjectType" => "User") }

    it { expect(result).to be_success }

    it "coerces singular subjectType into subject_types" do
      expect(result.input.subject_types).to eq(["User"])
    end
  end

  context "with subjectTypes array" do
    subject(:result) { described_class.call("subjectTypes" => %w[User Membership]) }

    it { expect(result).to be_success }

    it "accepts multi-value subject types" do
      expect(result.input.subject_types).to eq(%w[User Membership])
    end
  end

  context "with an invalid subjectType" do
    subject(:result) { described_class.call("subjectType" => "user") }

    it { expect(result).not_to be_success }
  end

  context "with an invalid eventName" do
    subject(:result) { described_class.call("eventName" => "Phone Updated") }

    it { expect(result).not_to be_success }
  end

  context "with an invalid occurredAfter" do
    subject(:result) { described_class.call("occurredAfter" => "yesterday") }

    it { expect(result).not_to be_success }
  end

  context "when limit exceeds the max" do
    subject(:result) { described_class.call("limit" => "101") }

    it { expect(result).not_to be_success }
  end
end

RSpec.describe CommandTower::Deserializers::Audit::Events::AdminListDeserializer do
  context "with admin identity filters" do
    subject(:result) do
      described_class.call(
        "affectedUserId" => "11",
        "attributionMode" => "impersonation"
      )
    end

    it { expect(result).to be_success }

    it "coerces admin-only filters" do
      expect(result.input).to have_attributes(affected_user_id: 11, attribution_mode: "impersonation")
    end
  end

  context "with an invalid affectedUserId" do
    subject(:result) { described_class.call("affectedUserId" => "abc") }

    it { expect(result).not_to be_success }
  end

  context "with an invalid attributionMode" do
    subject(:result) { described_class.call("attributionMode" => "superuser") }

    it { expect(result).not_to be_success }
  end
end
