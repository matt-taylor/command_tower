# frozen_string_literal: true

RSpec.describe CommandTower::Audit::Attribution do
  after { CommandTower::Current.reset }

  describe ".resolve" do
    context "when the actor and affected user match" do
      before do
        CommandTower::Current.user_id = 42
        CommandTower::Current.effective_user_id = 42
      end

      subject(:result) { described_class.resolve(affected_user_id: 42, attribution_mode: nil) }

      it "maps self-service" do
        expect(result[:attribution_mode]).to eq(:self_service)
        expect(result[:actor_user_id]).to eq(42)
        expect(result[:affected_user_id]).to eq(42)
        expect(result[:effective_user_id]).to eq(42)
        expect(result[:impersonation_active]).to eq(false)
        expect(result[:originating_administrator_id]).to be_nil
      end
    end

    context "when admin_direct is explicit" do
      before do
        CommandTower::Current.user_id = 7
        CommandTower::Current.effective_user_id = 7
      end

      subject(:result) { described_class.resolve(affected_user_id: 42, attribution_mode: :admin_direct) }

      it "keeps the administrator as actor" do
        expect(result[:attribution_mode]).to eq(:admin_direct)
        expect(result[:actor_user_id]).to eq(7)
        expect(result[:affected_user_id]).to eq(42)
        expect(result[:effective_user_id]).to eq(7)
        expect(result[:impersonation_active]).to eq(false)
      end
    end

    context "when actor and affected user differ without a mode" do
      before { CommandTower::Current.user_id = 7 }

      subject(:invoke) { described_class.resolve(affected_user_id: 42, attribution_mode: nil) }

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::Audit::InvalidAttributionError, /must be explicit/)
      end
    end

    context "when impersonation is active" do
      before do
        CommandTower::Current.user_id = 42
        CommandTower::Current.effective_user_id = 42
        CommandTower::Current.originating_administrator_id = 7
        CommandTower::Current.impersonation_active = true
      end

      subject(:result) { described_class.resolve(affected_user_id: 42, attribution_mode: nil) }

      it "uses the originating administrator as actor" do
        expect(result[:attribution_mode]).to eq(:impersonation)
        expect(result[:actor_user_id]).to eq(7)
        expect(result[:affected_user_id]).to eq(42)
        expect(result[:effective_user_id]).to eq(42)
        expect(result[:user_id]).to eq(42)
        expect(result[:originating_administrator_id]).to eq(7)
        expect(result[:impersonation_active]).to eq(true)
      end
    end

    context "when no human actor is present" do
      subject(:result) { described_class.resolve(affected_user_id: 42, attribution_mode: nil) }

      it "maps system" do
        expect(result[:attribution_mode]).to eq(:system)
        expect(result[:actor_user_id]).to be_nil
        expect(result[:affected_user_id]).to eq(42)
      end
    end

    context "when the mode is invalid" do
      subject(:invoke) { described_class.resolve(affected_user_id: 1, attribution_mode: :guess) }

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::Audit::InvalidAttributionError, /invalid attribution_mode/)
      end
    end
  end
end
