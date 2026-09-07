# frozen_string_literal: true

RSpec.describe "CommandTower experience states architecture" do
  let(:engine_root) { CommandTower::Engine.root }
  let(:serializer_source) do
    File.read(
      engine_root.join(
        "app/serializers/command_tower/serializers/me/experience_states/experience_state_serializer.rb",
      ),
    )
  end
  let(:controller_source) do
    File.read(engine_root.join("app/controllers/command_tower/me/experience_states_controller.rb"))
  end
  let(:model_source) do
    File.read(engine_root.join("app/models/command_tower/user_experience_state.rb"))
  end

  it "keeps serializers and controllers free of presentation instructions" do
    expect(serializer_source).not_to include("showWelcome")
    expect(serializer_source).not_to include("shouldShow")
    expect(controller_source).not_to include("showWelcome")
    expect(controller_source).not_to include("shouldShow")
  end

  it "keeps the model domain-blind" do
    expect(model_source).not_to match(/\b(League|Season|Tenant|Organization)\b/)
  end

  it "does not accept client-controlled host_key in the complete deserializer" do
    source = File.read(
      engine_root.join(
        "app/deserializers/command_tower/deserializers/me/experience_states/complete_deserializer.rb",
      ),
    )
    expect(source).not_to include(":hostKey")
    expect(source).not_to include(":host_key")
  end
end
