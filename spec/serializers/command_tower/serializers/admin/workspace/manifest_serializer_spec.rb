# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Admin::Workspace::ManifestSerializer do
  subject(:payload) do
    described_class.serialize(
      [
        {
          id: "audit",
          label: "Audit",
          description: "Browse account and administrative audit history.",
          route: "/admin/audit",
          group: "operations",
          sort_order: 100,
          icon: "history"
        }
      ]
    )
  end

  it "emits camelCase frontend metadata without RBAC internals" do
    expect(payload).to eq(
      tools: [
        {
          id: "audit",
          label: "Audit",
          description: "Browse account and administrative audit history.",
          route: "/admin/audit",
          group: "operations",
          sortOrder: 100,
          icon: "history"
        }
      ]
    )
  end
end
