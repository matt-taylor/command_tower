# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::Registry::InboxPresentations::PresentationDefinition do
  subject(:definition) { described_class.new }

  describe "#validate_definition!" do
    context "when composer_class and output_keys are both present" do
      before do
        definition.composer_class = "Services::Competitive::Presentations::MakePicks"
        definition.output_keys = [:picks]
      end

      it "normalizes output_keys to an Array of Symbols and does not raise" do
        expect { definition.validate_definition!(key: "pickem.make_picks") }.not_to raise_error
        expect(definition.output_keys).to eq([:picks])
      end
    end

    context "when output_keys is missing entirely" do
      before { definition.composer_class = "Services::Competitive::Presentations::MakePicks" }

      it "raises InvalidPresentationDefinitionError" do
        expect { definition.validate_definition!(key: "pickem.make_picks") }.to raise_error(
          CommandTower::InboxPresentations::InvalidPresentationDefinitionError,
          /output_keys/,
        )
      end
    end

    context "when output_keys is an empty array" do
      before do
        definition.composer_class = "Services::Competitive::Presentations::MakePicks"
        definition.output_keys = []
      end

      it "raises InvalidPresentationDefinitionError" do
        expect { definition.validate_definition!(key: "pickem.make_picks") }.to raise_error(
          CommandTower::InboxPresentations::InvalidPresentationDefinitionError,
          /output_keys/,
        )
      end
    end

    context "when output_keys contains a blank entry" do
      before do
        definition.composer_class = "Services::Competitive::Presentations::MakePicks"
        definition.output_keys = [:picks, ""]
      end

      it "raises InvalidPresentationDefinitionError" do
        expect { definition.validate_definition!(key: "pickem.make_picks") }.to raise_error(
          CommandTower::InboxPresentations::InvalidPresentationDefinitionError,
          /output_keys/,
        )
      end
    end

    context "when output_keys entries are Strings rather than Symbols" do
      before do
        definition.composer_class = "Services::Competitive::Presentations::MakePicks"
        definition.output_keys = ["picks", "games"]
      end

      it "normalizes them to Symbols" do
        definition.validate_definition!(key: "pickem.make_picks")

        expect(definition.output_keys).to eq([:picks, :games])
      end
    end
  end
end
