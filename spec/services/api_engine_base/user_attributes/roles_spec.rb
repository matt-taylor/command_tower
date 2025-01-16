# frozen_string_literal: true

RSpec.describe ApiEngineBase::UserAttributes::Roles do
  before do
    ApiEngineBase::Authorization::Role.roles_reset!
    ApiEngineBase::Authorization::Entity.entities_reset!
    ApiEngineBase::Authorization.mapped_controllers_reset!
    ApiEngineBase::Authorization.default_defined!
  end

  after do
    ApiEngineBase::Authorization::Role.roles_reset!
    ApiEngineBase::Authorization::Entity.entities_reset!
    ApiEngineBase::Authorization.mapped_controllers_reset!
  end

  let(:user) { create(:user, :role_owner) }
  let(:admin_user) { create(:user, :role_owner) }

  let(:params) do
    {
      user:,
      admin_user:,
      roles:,
    }
  end
  let(:roles) { [] }

  describe ".call" do
    subject(:call) { described_class.(**params) }

    it "succeeds" do
      expect(call.success?).to be(true)
    end

    it "changes value" do
      expect { call }.to change { user.reload.roles }.to([])
    end

    context "with invalid role" do
      let(:roles) { ["invalid role name"] }

      it "fails" do
        expect(call.failure?).to be(true)
      end

      it "sets context values" do
        expect(call.msg).to include("Invalid arguments: roles")
        expect(call.invalid_argument_keys).to eq([:roles])
        expect(call.invalid_arguments).to be(true)
      end

      it "does not change value" do
        expect { call }.to_not change { user.reload.roles }
      end
    end

    context "with valid role" do
      let(:roles) { ApiEngineBase::Authorization::Role.roles.keys }

      it "succeeds" do
        expect(call.success?).to be(true)
      end

      it "changes value" do
        expect { call }.to change { user.reload.roles.sort }.to(roles.sort)
      end
    end
  end
end
