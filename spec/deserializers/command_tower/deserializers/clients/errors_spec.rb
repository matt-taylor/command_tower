# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Clients::Errors do
  describe ".prefix" do
    subject(:prefixed) { described_class.prefix(error, segment) }

    let(:error) do
      CommandTower::Clients::Errors::DeserializationError.new(
        message: "bad",
        details: {
          path: current_path,
          expected: "integer",
          actual: "String",
          rule: "type",
          messages: [ "bad" ]
        }
      )
    end

    context "when prefixing a scalar path with a field name" do
      let(:current_path) { "id" }
      let(:segment) { "region" }

      it "joins with a dot" do
        expect(prefixed.details[:path]).to eq("region.id")
        expect(prefixed.details[:expected]).to eq("integer")
        expect(prefixed.details[:actual]).to eq("String")
        expect(prefixed.details[:rule]).to eq("type")
        expect(prefixed.details[:messages]).to eq([ "bad" ])
      end
    end

    context "when prefixing with a list index" do
      let(:current_path) { "name" }
      let(:segment) { "[2]" }

      it "places the index outside the field" do
        expect(prefixed.details[:path]).to eq("[2].name")
      end
    end

    context "when the current path is already an index" do
      let(:current_path) { "[1]" }
      let(:segment) { "addresses" }

      it "concatenates as a bracket path" do
        expect(prefixed.details[:path]).to eq("addresses[1]")
      end
    end

    context "when the current path is blank" do
      let(:current_path) { "" }
      let(:segment) { "pagination" }

      it "uses the segment alone" do
        expect(prefixed.details[:path]).to eq("pagination")
      end
    end

    context "when the error is not a DeserializationError" do
      subject(:invoke) { described_class.prefix(StandardError.new("x"), "region") }

      it "raises ConfigurationError" do
        expect { invoke }.to raise_error(CommandTower::Clients::Errors::ConfigurationError, /DeserializationError/)
      end
    end
  end
end
