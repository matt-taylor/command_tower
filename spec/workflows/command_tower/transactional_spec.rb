# frozen_string_literal: true

RSpec.describe CommandTower::Transactional do
  describe "platform isolation" do
    subject(:source) do
      File.read(CommandTower::Engine.root.join("app/workflows/command_tower/transactional.rb"))
    end

    it "does not reference Jumbotron" do
      expect(source).not_to include("Jumbotron")
    end
  end
end
