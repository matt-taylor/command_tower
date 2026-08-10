# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Messaging::Inbox::ItemSerializer do
  subject(:payload) do
    described_class.serialize(
      id: 1, title: "Notice", status: "created", viewed_at: nil,
      created_at: Time.zone.parse("2026-01-01 12:00:00"), updated_at: Time.zone.parse("2026-01-01 12:00:00")
    )
  end

  it "uses the modern inbox response keys" do
    expect(payload).to include(id: 1, read: false, viewedAt: nil)
  end
end
