# frozen_string_literal: true

RSpec.describe "Messaging Accept path clarification architecture" do
  let(:messaging_facade_source) do
    File.read(CommandTower::Engine.root.join("app/services/command_tower/messaging.rb"))
  end

  it "façade invokes Accept::Coordinator" do
    expect(messaging_facade_source).to include("Accept::Coordinator.call")
    expect(messaging_facade_source).not_to include("Accept::Workflow")
  end

  it "defines Accept::Coordinator and not Accept::Workflow" do
    expect(defined?(CommandTower::Messaging::Accept::Coordinator)).to eq("constant")
    expect(defined?(CommandTower::Messaging::Accept::Workflow)).to be_nil
  end

  it "Accept::Coordinator is a domain PORO, not an ApplicationWorkflow" do
    expect(CommandTower::Messaging::Accept::Coordinator).not_to be <
      CommandTower::Workflows::ApplicationWorkflow
  end

  it "removes Contract::Communications.record write path" do
    expect(CommandTower::Messaging::Contract::Communications).not_to respond_to(:record)
    expect(defined?(CommandTower::Messaging::Contract::Internal::Recorder)).to be_nil
    expect(defined?(CommandTower::Messaging::Contract::Requests::RecordCommunication)).to be_nil
  end

  it "keeps Contract::Communications.find for Inbox" do
    expect(CommandTower::Messaging::Contract::Communications).to respond_to(:find)
    expect(defined?(CommandTower::Messaging::Contract::Internal::Finder)).to eq("constant")
  end
end
