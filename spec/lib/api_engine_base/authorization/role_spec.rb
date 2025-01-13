# frozen_string_literal: true

RSpec.describe ApiEngineBase::Authorization::Role do
  let(:entity) { build(:entity)}
  let(:entity_only) { build(:entity, :only)}
  let(:entity_except) { build(:entity, :except)}
  let(:params) do
    {
      name:,
      description: "This is some description that does not matter",
      entities:,
      allow_everything:
    }
  end
  let(:name) { Faker::Lorem.word }
  let(:allow_everything) { false }
  let(:instance) { described_class.new(**params) }
  let(:entities) { entity }
  let(:user) { create(:user) }

  describe ".create_role" do
    subject(:create_role) { described_class.create_role(**params) }
    before do
      described_class.roles_reset!
    end

    after do
      described_class.roles_reset!
    end

    context "with duplicate role" do
      before { described_class.create_role(**params) }

      it "raises" do
        expect { described_class.create_role(**params) }.to raise_error(ApiEngineBase::Authorization::Error, /Must use different name/)
      end
    end

    context "with allow_everything" do
      let(:allow_everything) { true }

      it "saves role allow_everything" do
        expect(described_class.roles.length).to eq(0)
        create_role
        expect(described_class.roles.length).to eq(1)
        expect(described_class.roles[name].allow_everything).to eq(true)
      end
    end

    context "when incorrect entities" do
      let(:entities) { 5 }

      it "raises" do
        expect { described_class.create_role(**params) }.to raise_error(ApiEngineBase::Authorization::Error, /Parameter :entities must include objects of or inherited by/)
      end
    end

    context "with customized entity" do
      let(:attributes) { attributes_for(:entity, :only) }
      let(:entity) { custom_entity.new(**attributes) }
      let(:custom_entity) do
        Class.new(ApiEngineBase::Authorization::Entity) do
          def authorized?(user:)
            user.email_validated
          end
        end
      end

      before do
        attributes[:controller].define_method(attributes[:only]) {}
      end

      it "creates role with custom entity" do
        expect(described_class.roles.length).to eq(0)
        create_role
        expect(described_class.roles.length).to eq(1)
        expect(described_class.roles[name].entities).to include(entity)
      end
    end

    context "with entity array" do
      let(:entities) { build_list(:entity, count) }
      let(:count) { 5 }

      it "creates role with multiple entities" do
        expect(described_class.roles.length).to eq(0)

        create_role

        expect(described_class.roles.length).to eq(1)
        expect(described_class.roles[name]).to be_present
        expect(described_class.roles[name].entities.count).to eq(count)
      end
    end

    it "creates role" do
      expect(described_class.roles.length).to eq(0)
      create_role
      expect(described_class.roles.length).to eq(1)
      expect(described_class.roles[name].entities).to include(entity)
    end
  end

  describe "#authorized?" do
    subject(:authorized) { instance.authorized?(controller:, method:, user:) }
    let(:controller) { entity.controller }
    let(:method) { "some_method" }

    context "when allow_everything is true" do
      let(:allow_everything) { true }

      it "returns authorized true" do
        is_expected.to include(
          role: params[:name],
          description: be_a(String),
          authorized: true,
          reason: /allows all authorizations/,
        )
      end
    end

    context "when role does not have controller" do
      let(:controller) { Class.new(::ApiEngineBase::ApplicationController) }

      it "returns authorized nil" do
        is_expected.to include(
          role: params[:name],
          description: be_a(String),
          authorized: nil,
          reason: /does not match/,
        )
      end
    end

    context "when entity returns false" do
      let(:entity) { build(:entity, :only) }

      it "returns authorized false" do
        is_expected.to include(
          role: params[:name],
          description: be_a(String),
          authorized: false,
          reason: "Subset of Entities Rejected authorization",
          rejected_entities: [
            hash_including(authorized: false, entity: entity.name, status: "Rejected by inclusion")
          ]
        )
      end
    end

    context "when entity returns true" do
      let(:entity) { build(:entity, :only) }
      let(:method) { entity.only.sample }

      it "returns authorized true" do
        is_expected.to include(
          role: params[:name],
          description: be_a(String),
          authorized: true,
          reason: "All entities approve authorization",
        )
      end

      context "with full controller" do
        let(:entity) { build(:entity) }
        let(:method) { "method does not matter"}

        it "returns authorized true" do
          is_expected.to include(
            role: params[:name],
            description: be_a(String),
            authorized: true,
            reason: "All entities approve authorization",
          )
        end
      end

      context "with custom authorized entity" do
        let(:attributes) { attributes_for(:entity, :only) }
        let(:entity) { custom_entity.new(**attributes) }
        let(:custom_entity) do
          Class.new(ApiEngineBase::Authorization::Entity) do
            def authorized?(user:)
              user.email_validated
            end
          end
        end

        before do
          attributes[:controller].define_method(attributes[:only]) {}
        end

        it "returns authorized true" do
          is_expected.to include(
            role: params[:name],
            description: be_a(String),
            authorized: true,
            reason: "All entities approve authorization",
          )
        end

        context "when authorized returns false" do
          let(:user) { create(:user, :unvalidated_email)}

          it "returns authorized false" do
            is_expected.to include(
              role: params[:name],
              description: be_a(String),
              authorized: false,
              reason: "Subset of Entities Rejected authorization",
              rejected_entities: [
                hash_including(authorized: false, entity: entity.name, status: "Rejected via custom Entity Authorization")
              ]
            )
          end
        end
      end
    end
  end

  describe "#guards" do
    subject(:guards) { instance.guards }

    let(:additional_methods) { Faker::Lorem.words(number: additional_method_count) }
    let(:additional_method_count) { 2 }
    let(:method_name) { Faker::Lorem.word }

    context "with only" do
      let(:entity) { build(:entity, :only, method_name:, additional_methods:) }

      it "contains only" do
        expect(guards[entity.controller]).to eq([method_name].map(&:to_sym))
      end
    end

    context "with except" do
      let(:entity) { build(:entity, :except, method_name:, additional_methods:) }

      it "contains all but except" do
        expect(guards[entity.controller].sort).to eq(additional_methods.sort.map(&:to_sym))
      end

      it "does not contain except" do
        expect(guards[entity.controller]).to_not include(method_name)
      end
    end

    context "when entire controller is added" do
      let(:entity) { build(:entity,  additional_methods:) }

      it "contains all methods" do
        expect(guards[entity.controller].sort).to eq(entity.controller.instance_methods(false).sort)
      end
    end
  end
end
