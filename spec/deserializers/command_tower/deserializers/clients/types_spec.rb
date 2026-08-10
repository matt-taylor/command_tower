# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Clients::Types do
  describe ".integer" do
    subject(:type) { described_class.integer }

    it "accepts Integer" do
      expect(type.call(42, path: "id")).to eq(42)
    end

    it "coerces whole-number strings" do
      expect(type.call("7", path: "id")).to eq(7)
    end

    context "when the value is not a whole-number string" do
      subject(:invoke) { type.call("12.5", path: "id") }

      it "raises DeserializationError" do
        expect { invoke }.to raise_error(CommandTower::Clients::Errors::DeserializationError) do |error|
          expect(error.details).to include(path: "id", expected: "integer", rule: "type")
          expect(error.details[:actual]).to eq("String")
        end
      end
    end

    context "when the value is a Hash" do
      subject(:invoke) { type.call({}, path: "id") }

      it "raises DeserializationError" do
        expect { invoke }.to raise_error(CommandTower::Clients::Errors::DeserializationError)
      end
    end
  end

  describe ".string" do
    subject(:type) { described_class.string }

    it "accepts String only" do
      expect(type.call("ok", path: "name")).to eq("ok")
    end

    context "when the value is an Integer" do
      subject(:invoke) { type.call(1, path: "name") }

      it "rejects without String() coercion" do
        expect { invoke }.to raise_error(CommandTower::Clients::Errors::DeserializationError) do |error|
          expect(error.details).to include(path: "name", expected: "string", actual: "Integer")
        end
      end
    end
  end

  describe ".boolean" do
    subject(:type) { described_class.boolean }

    it "accepts true and false only" do
      expect(type.call(true, path: "flag")).to eq(true)
      expect(type.call(false, path: "flag")).to eq(false)
    end

    context "when the value is a truthy string" do
      subject(:invoke) { type.call("true", path: "flag") }

      it "raises DeserializationError" do
        expect { invoke }.to raise_error(CommandTower::Clients::Errors::DeserializationError)
      end
    end
  end

  describe ".array" do
    subject(:type) { described_class.array(described_class.string) }

    it "validates each member" do
      expect(type.call(%w[a b], path: "tags")).to eq(%w[a b])
    end

    context "when a member is invalid" do
      subject(:invoke) { type.call([ "a", 1 ], path: "tags") }

      it "includes the index in the path" do
        expect { invoke }.to raise_error(CommandTower::Clients::Errors::DeserializationError) do |error|
          expect(error.details[:path]).to eq("tags[1]")
        end
      end
    end

    context "when the value is not an Array" do
      subject(:invoke) { type.call("x", path: "tags") }

      it "raises DeserializationError" do
        expect { invoke }.to raise_error(CommandTower::Clients::Errors::DeserializationError)
      end
    end

    context "when element type is nil" do
      subject(:invoke) { described_class.array(nil) }

      it "raises ConfigurationError" do
        expect { invoke }.to raise_error(CommandTower::Clients::Errors::ConfigurationError, /nil/)
      end
    end
  end

  describe ".union" do
    subject(:type) { described_class.union(described_class.string, described_class.array(described_class.string)) }

    it "accepts the first matching member" do
      expect(type.call("one", path: "formatted_address")).to eq("one")
      expect(type.call(%w[a b], path: "formatted_address")).to eq(%w[a b])
    end

    context "when no member matches" do
      subject(:invoke) { type.call(12, path: "formatted_address") }

      it "raises DeserializationError" do
        expect { invoke }.to raise_error(CommandTower::Clients::Errors::DeserializationError) do |error|
          expect(error.details[:path]).to eq("formatted_address")
        end
      end
    end
  end
end
