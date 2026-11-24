# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Definitions::RenderContext do
  subject(:context) do
    described_class.new(
      notification_type_key: "class_canceled",
      metadata: { "class_name" => "Arms" },
      metadata_version: 1,
      slots: nil,
      render_zone: "America/New_York"
    )
  end

  it "exposes its five members", :aggregate_failures do
    expect(described_class.members)
      .to eq(%i[notification_type_key metadata metadata_version slots render_zone])
    expect(context.notification_type_key).to eq("class_canceled")
    expect(context.render_zone).to eq("America/New_York")
  end

  it "is immutable", :aggregate_failures do
    expect(context).to be_frozen
    expect { context.instance_variable_set(:@render_zone, "UTC") }.to raise_error(FrozenError)
  end
end
