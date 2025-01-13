# frozen_string_literal: true

RSpec.describe ApiEngineBase::Authorization::Entity do
  let(:method_count) { 5 }
  let(:method_names) { Faker::Lorem.words(number: method_count) }
  let(:params) do
    {
      except:,
      name:,
      only:,
      controller: controller_input,
    }
  end
  let(:name) { Faker::Lorem.word }
  let(:controller) { Class.new(::ApiEngineBase::ApplicationController) }
  let(:controller_input) { controller }
  let(:only) { nil }
  let(:except) { nil }
  let(:instance) { described_class.new(**params) }

  before do
    described_class.entities_reset!
    method_names.each do
      controller.define_method(_1) do
      end
    end
  end

  after { described_class.entities_reset! }

  describe ".create_entity" do
    it "adds entity" do
      expect(described_class.entities.keys).to eq([])

      described_class.create_entity(**params)

      expect(described_class.entities.keys).to include(name)
    end

    context "when already exists" do
      it "overrides entity with warning" do
        expect(described_class.entities.keys).to eq([])
        described_class.create_entity(**params)
        described_class.create_entity(**params)
        expect(described_class.entities.keys).to include(name)
      end
    end
  end

  describe ".entities_reset!" do
    subject(:entities_reset) { described_class.entities_reset! }

    it "clears list of entities" do
      described_class.create_entity(**params)
      described_class.create_entity(**params, name: "other Name")
      expect(described_class.entities.length).to eq(2)

      entities_reset

      expect(described_class.entities.length).to eq(0)
    end
  end

  describe "#initialize" do
    subject { instance }

    context "when only and except passed in" do
      let(:only) { method_names[0] }
      let(:except) { method_names[1] }

      it do
        expect { subject }.to raise_error(ApiEngineBase::Authorization::Error, /At most 1 can be passed in/)
      end
    end

    context "when controller is not valid" do
      let(:controller_input) { "ClassThatDoesNotExist" }

      it do
        expect { subject }.to raise_error(ApiEngineBase::Authorization::Error, /was not found/)
      end
    end

    context "when methods do not exist" do
      context "when only" do
        let(:only) { "method_that_does_not_exist" }

        it do
          expect { subject }.to raise_error(ApiEngineBase::Authorization::Error, /only parameter is invalid/)
        end
      end

      context "when except" do
        let(:except) { "method_that_does_not_exist" }

        it do
          expect { subject }.to raise_error(ApiEngineBase::Authorization::Error, /except parameter is invalid/)
        end
      end
    end

    context "with only" do
      let(:only) { method_names[0] }

      it "passes" do
        expect { subject }.to_not raise_error
      end

      context "with array" do
        let(:only) { method_names }

        it "passes" do
          expect { subject }.to_not raise_error
        end
      end
    end

    context "with except" do
      let(:except) { method_names[0] }

      it "passes" do
        expect { subject }.to_not raise_error
      end

      context "with array" do
        let(:except) { method_names }

        it "passes" do
          expect { subject }.to_not raise_error
        end
      end
    end

    it "passes" do
      expect { subject }.to_not raise_error
    end
  end

  describe "#humanize" do
    subject(:humanize) { instance.humanize }

    it do
      expect { humanize }.to_not raise_error
    end
  end

  describe "#authorized?" do
    subject(:authorized) { instance.authorized?(user:) }
    let(:user) { create(:user) }

    it do
      is_expected.to be(true)
    end
  end

  describe "#matches?" do
    subject(:matches) { instance.matches?(controller: matches_controller, method: matches_method) }

    let(:matches_controller) { controller }
    let(:matches_method) { method_names[0] }

    context "with matching controller" do

      context "without only and without except" do
        it "matches all controller methods" do
          is_expected.to be(true)
        end
      end

      context "with only" do
        let(:only) { method_names[0] }

        context "with matching method" do
          it do
            is_expected.to be(true)
          end
        end

        context "with mis-matched method" do
          let(:matches_method) { "mismatched_method_name" }

          it do
            is_expected.to be(false)
          end
        end
      end

      context "with except" do
        let(:except) { method_names[0] }

        context "with matching method" do
          it do
            is_expected.to be(false)
          end
        end

        context "with mis-matched method" do
          let(:matches_method) { "mismatched_method_name" }

          it do
            is_expected.to be(true)
          end
        end
      end
    end

    context "with mismatched controller" do
      let(:matches_controller) { described_class }

      it do
        is_expected.to be_nil
      end
    end
  end
end
