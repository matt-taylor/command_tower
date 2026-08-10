# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Clients::Result do
  describe ".field / .build!" do
    let(:sample_result_class) do
      Class.new(described_class) do
        field :id, type: CommandTower::Deserializers::Clients::Types.integer, required: true
        field :name, type: CommandTower::Deserializers::Clients::Types.string, required: true
        field :nickname, type: CommandTower::Deserializers::Clients::Types.string, nullable: true
        field :label, type: CommandTower::Deserializers::Clients::Types.string
        field :tags,
              type: CommandTower::Deserializers::Clients::Types.array(CommandTower::Deserializers::Clients::Types.string),
              default: -> { [] }
      end
    end

    describe "required vs nullable matrix" do
      context "when a required field is Missing" do
        subject(:invoke) do
          sample_result_class.build!(
            id: CommandTower::Deserializers::Clients::Missing,
            name: "Studio"
          )
        end

        it "fails with rule required" do
          expect { invoke }.to raise_error(CommandTower::Clients::Errors::DeserializationError) do |error|
            expect(error.details).to include(path: "id", rule: "required")
          end
        end
      end

      context "when a required non-nullable field is explicit nil" do
        subject(:invoke) { sample_result_class.build!(id: nil, name: "Studio") }

        it "fails with rule nullable" do
          expect { invoke }.to raise_error(CommandTower::Clients::Errors::DeserializationError) do |error|
            expect(error.details).to include(path: "id", rule: "nullable")
          end
        end
      end

      context "when a nullable field is explicit nil" do
        subject(:result) { sample_result_class.build!(id: 1, name: "Studio", nickname: nil) }

        it "stores nil" do
          expect(result.nickname).to be_nil
        end
      end

      context "when an optional field is Missing" do
        subject(:result) do
          sample_result_class.build!(
            id: 1,
            name: "Studio",
            nickname: CommandTower::Deserializers::Clients::Missing,
            label: CommandTower::Deserializers::Clients::Missing
          )
        end

        it "stores nil without a declared default" do
          expect(result.nickname).to be_nil
          expect(result.label).to be_nil
        end
      end

      context "when an optional non-nullable field is explicit nil" do
        subject(:invoke) { sample_result_class.build!(id: 1, name: "Studio", label: nil) }

        it "fails with rule nullable" do
          expect { invoke }.to raise_error(CommandTower::Clients::Errors::DeserializationError) do |error|
            expect(error.details).to include(path: "label", rule: "nullable")
          end
        end
      end
    end

    describe "defaults" do
      context "when a field declares a Proc default" do
        subject(:result) do
          sample_result_class.build!(
            id: 1,
            name: "Studio",
            tags: CommandTower::Deserializers::Clients::Missing
          )
        end

        it "materializes a fresh default per build" do
          expect(result.tags).to eq([])
          result.tags << "x"
          expect(
            sample_result_class.build!(
              id: 2,
              name: "Other",
              tags: CommandTower::Deserializers::Clients::Missing
            ).tags
          ).to eq([])
        end
      end

      context "when a shared mutable default is declared" do
        subject(:invoke) do
          Class.new(described_class) do
            field :items,
                  type: CommandTower::Deserializers::Clients::Types.array(CommandTower::Deserializers::Clients::Types.string),
                  default: []
          end
        end

        it "raises ConfigurationError at declaration time" do
          expect { invoke }.to raise_error(CommandTower::Clients::Errors::ConfigurationError, /Proc/)
        end
      end
    end

    describe "nested Result instance checks" do
      let(:region_result_class) do
        Class.new(described_class) do
          field :id, type: CommandTower::Deserializers::Clients::Types.integer, required: true
        end
      end

      let(:location_result_class) do
        region = region_result_class
        Class.new(described_class) do
          field :region, type: region, required: true
        end
      end

      context "when the value is a Hash" do
        subject(:invoke) { location_result_class.build!(region: { "id" => 1 }) }

        it "rejects without auto Hash→Result conversion" do
          expect { invoke }.to raise_error(CommandTower::Clients::Errors::DeserializationError) do |error|
            expect(error.details[:path]).to eq("region")
            expect(error.details[:rule]).to eq("type")
          end
        end
      end

      context "when the value is the expected Result instance" do
        subject(:result) do
          location_result_class.build!(region: region_result_class.build!(id: 9))
        end

        it "accepts the instance" do
          expect(result.region.id).to eq(9)
        end
      end
    end

    describe "declaration defects" do
      context "when type is an unknown object" do
        subject(:invoke) do
          Class.new(described_class) do
            field :id, type: :integer, required: true
          end
        end

        it "raises ConfigurationError" do
          expect { invoke }.to raise_error(CommandTower::Clients::Errors::ConfigurationError, /unknown type/)
        end
      end

      context "when nested type is not a Result subclass" do
        subject(:invoke) do
          Class.new(described_class) do
            field :region, type: String, required: true
          end
        end

        it "raises ConfigurationError" do
          expect { invoke }.to raise_error(CommandTower::Clients::Errors::ConfigurationError, /Result subclass/)
        end
      end
    end
  end
end
