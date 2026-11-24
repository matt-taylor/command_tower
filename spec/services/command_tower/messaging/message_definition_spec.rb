# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::MessageDefinition do
  let(:metadata_class) do
    Class.new(described_class::Metadata) do
      attribute :class_name, :string
      attribute :seats, :integer
      validates :class_name, presence: true
    end
  end

  let(:definition_class) do
    schema = metadata_class
    Class.new(described_class) do
      metadata_version 2
      metadata_schema schema
      default_zone "America/Los_Angeles"
      promotional true
      required_fact :class_name, :text
      required_fact :starts_at, :time, zone: "studio_zone"
      required_fact :window, :time, zone: :user, optional: true
      fixture :default, metadata: { class_name: "Arms", "seats" => 3 }
    end
  end

  let(:bare_class) { Class.new(described_class) }

  describe "macros" do
    it "reads back the declared values", :aggregate_failures do
      expect(definition_class.metadata_version).to eq(2)
      expect(definition_class.default_zone).to eq("America/Los_Angeles")
      expect(definition_class.promotional?).to be(true)
      expect(definition_class.metadata_schema).to eq(metadata_class)
    end

    it "defaults promotional to false and the schema to the base Metadata", :aggregate_failures do
      expect(bare_class.promotional?).to be(false)
      expect(bare_class.metadata_schema).to eq(described_class::Metadata)
    end

    it "has no version, zone, fixtures or facts until declared", :aggregate_failures do
      expect(bare_class.metadata_version).to be_nil
      expect(bare_class.default_zone).to be_nil
      expect(bare_class.fixtures).to eq({})
      expect(bare_class.required_facts).to eq([])
    end

    it "records required facts with string keys and zones", :aggregate_failures do
      expect(definition_class.required_facts.map(&:key)).to eq(%w[class_name starts_at window])
      expect(definition_class.required_facts.map(&:matcher)).to eq(%i[text time time])
      expect(definition_class.required_facts.map(&:zone)).to eq([nil, "studio_zone", :user])
      expect(definition_class.required_facts.map(&:optional)).to eq([false, false, true])
    end

    context "with a matcher class" do
      let(:declare) do
        matcher = Class.new
        -> { Class.new(described_class) { required_fact :x, matcher } }
      end

      it "accepts it" do
        expect(&declare).not_to raise_error
      end
    end

    it "rejects any other matcher" do
      expect { Class.new(described_class) { required_fact :x, :bogus } }
        .to raise_error(ArgumentError, /matcher/)
    end

    it "stores fixtures with string keys, frozen", :aggregate_failures do
      expect(definition_class.fixtures.keys).to eq(["default"])
      expect(definition_class.fixtures["default"]).to eq("class_name" => "Arms", "seats" => 3)
      expect(definition_class.fixtures["default"]).to be_frozen
    end
  end

  describe "inheritance" do
    let(:child) do
      Class.new(definition_class) do
        required_fact :extra, :text
        fixture :other, metadata: { "class_name" => "Core" }
      end
    end

    it "inherits settings", :aggregate_failures do
      expect(child.metadata_version).to eq(2)
      expect(child.default_zone).to eq("America/Los_Angeles")
      expect(child.promotional?).to be(true)
    end

    it "extends facts and fixtures", :aggregate_failures do
      expect(child.required_facts.map(&:key)).to eq(%w[class_name starts_at window extra])
      expect(child.fixtures.keys).to eq(%w[default other])
    end

    it "does not mutate the parent", :aggregate_failures do
      child
      expect(definition_class.required_facts.size).to eq(3)
      expect(definition_class.fixtures.keys).to eq(["default"])
    end
  end

  describe ":basic instance defaults" do
    subject(:definition) { described_class.new }

    let(:builder) { Struct.new(:basic).new(:basic_layout) }

    it "returns no fact block" do
      expect(definition.facts(Object.new, metadata: {})).to be_nil
    end

    it "delegates inbox and email to the builder's basic layout", :aggregate_failures do
      expect(definition.inbox(builder, metadata: {})).to eq(:basic_layout)
      expect(definition.email(builder, metadata: {})).to eq(:basic_layout)
    end

    it "reads the headline from metadata" do
      expect(definition.headline(metadata: { "headline" => "Hello" })).to eq("Hello")
    end

    it "puts the headline in slots" do
      expect(definition.slots(metadata: { "headline" => "Hello" }, t: nil)).to eq(headline: "Hello")
    end
  end

  describe "overriding" do
    let(:klass) do
      Class.new(described_class) do
        def headline(metadata:) = "Canceled: #{metadata['class_name']}"
      end
    end

    it "lets a subclass override instance methods" do
      expect(klass.new.slots(metadata: { "class_name" => "Arms" }, t: nil))
        .to eq(headline: "Canceled: Arms")
    end
  end

  describe "Metadata" do
    let(:schema) { metadata_class }

    it "builds from string or symbol keys and ignores unknown keys", :aggregate_failures do
      expect(schema.from_hash("class_name" => "Arms", seats: "4", "junk" => 1))
        .to have_attributes(class_name: "Arms", seats: 4)
    end

    it "reports invalid attribute names only, never values", :aggregate_failures do
      expect(schema.schema_errors("class_name" => "")).to eq(["class_name"])
      expect(schema.schema_errors({})).to eq(["class_name"])
    end

    it "returns no errors for valid metadata" do
      expect(schema.schema_errors("class_name" => "Arms")).to eq([])
    end
  end
end
