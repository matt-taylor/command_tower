# frozen_string_literal: true

RSpec.describe CommandTower::Authorization do
  before do
    described_class::Role.roles_reset!
    described_class::Entity.entities_reset!
    described_class.mapped_controllers_reset!
  end

  after do
    described_class::Role.roles_reset!
    described_class::Entity.entities_reset!
    described_class.mapped_controllers_reset!
  end

  describe ".provision_rbac_default!" do
    subject(:provision_rbac_default) { described_class.provision_rbac_default! }

    it "creates owner" do
      subject
      expect(described_class::Role.roles["owner"]).to be_present
    end

    it "creates admin" do
      subject
      expect(described_class::Role.roles["admin"]).to be_present
    end

    it "creates admin-without-impersonation" do
      subject
      expect(described_class::Role.roles["admin-without-impersonation"]).to be_present
    end

    it "creates admin-read-only" do
      subject
      expect(described_class::Role.roles["admin-read-only"]).to be_present
    end
  end

  describe ".add_mapping!" do
    subject(:add_mapping) { described_class.add_mapping!(role:) }

    let(:only_entity) { build(:entity, :additional_methods, :only)}
    let(:except_entity) { build(:entity, :additional_methods, :except)}

    let(:only_role) { build(:role, entities: only_entity) }
    let(:except_role) { build(:role, entities: except_entity) }

    context "when except_role" do
      let(:role) { except_role }

      it "adds to mapping" do
        expect { add_mapping }.to_not raise_error

        expect(described_class.mapped_controllers.length).to eq(1)
        expect(described_class.mapped_controllers[except_entity.controller].sort).to_not include(except_entity.except)
      end
    end

    context "when only_role" do
      let(:role) { only_role }

      it "adds to mapping" do
        expect { add_mapping }.to_not raise_error

        expect(described_class.mapped_controllers.length).to eq(1)
        expect(described_class.mapped_controllers[only_entity.controller].sort).to eq(only_entity.only)
      end
    end

    context "with multiple roles on same controller" do
      before { described_class.add_mapping!(role: only_role) }

      let(:full_entity) { build(:entity, :additional_methods, controller:)}
      let(:only_entity) { build(:entity, :additional_methods, :only, controller:)}
      let(:controller) { Class.new(::CommandTower::ApplicationController) }
      let(:role) { build(:role, entities: [full_entity, only_entity]) }

      it "includes all methods on controller" do
        expect { add_mapping }.to_not raise_error

        expect(described_class.mapped_controllers.length).to eq(1)
        expect(described_class.mapped_controllers[controller].sort).to eq(controller.instance_methods(false).sort)
      end
    end
  end
end
