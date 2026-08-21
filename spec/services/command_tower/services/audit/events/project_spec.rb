# frozen_string_literal: true

RSpec.describe CommandTower::Services::Audit::Events::Project do
  let(:phone) { "+14155551212" }
  let(:event) do
    create_audit_event!(
      action: "phone_updated",
      affected_user_id: 11,
      actor_user_id: 11,
      subject_type: "User",
      subject_id: 11,
      subject_label: "member",
      change_set: {
        "phone" => { "from" => phone, "to" => "+14155559999" },
        "role" => { "from" => "member", "to" => "member" }
      },
      metadata: { "phone" => phone },
      sensitive_fields: ["phone"]
    )
  end

  describe ".call" do
    subject(:result) { described_class.call(event:, viewer: :user) }

    it { expect(result).to be_success }

    it "masks sensitive change from/to and leaves non-sensitive changes" do
      expect(result.data[:projection][:changes]["phone"]).to eq("from" => "*******1212", "to" => "*******9999")
      expect(result.data[:projection][:changes]["role"]).to eq("from" => "member", "to" => "member")
    end

    it "does not mask metadata" do
      expect(result.data[:projection][:metadata]).to eq("phone" => phone)
    end

    it "does not mutate the ledger row" do
      result
      expect(event.reload.change_set.dig("phone", "from")).to eq(phone)
    end

    it "does not return unmasked sensitive change values" do
      expect(result.data[:projection][:changes].to_json).not_to include(phone)
      expect(result.data[:projection][:changes].to_json).not_to include("+14155559999")
    end

    context "when the current registry is more restrictive than the snapshot" do
      let(:event) do
        create_audit_event!(
          action: "password_changed",
          change_set: { "email" => { "from" => "matt@example.com", "to" => "new@example.com" } },
          sensitive_fields: []
        )
      end

      before do
        definition = CommandTower.config.registry.audit.fetch(:password_changed)
        allow(definition).to receive(:sensitive_fields).and_return([:email])
      end

      it "masks the union of snapshot and current keys" do
        expect(result.data[:projection][:changes]["email"]).to eq(
          "from" => "m***@example.com",
          "to" => "n***@example.com"
        )
      end
    end

    context "when the current registry would be less restrictive" do
      let(:event) do
        create_audit_event!(
          action: "phone_updated",
          change_set: { "phone" => { "from" => phone, "to" => nil } },
          sensitive_fields: ["phone"]
        )
      end

      before do
        definition = CommandTower.config.registry.audit.fetch(:phone_updated)
        allow(definition).to receive(:sensitive_fields).and_return([])
      end

      it "still masks snapshot-sensitive keys" do
        expect(result.data[:projection][:changes]["phone"]).to eq("from" => "*******1212", "to" => nil)
      end
    end

    context "when the action is no longer registered" do
      let(:event) do
        create_audit_event!(
          action: "retired_phone_fact",
          change_set: { "phone" => { "from" => phone, "to" => nil } },
          sensitive_fields: ["phone"]
        )
      end

      it "masks from the snapshot only" do
        expect(result.data[:projection][:changes]["phone"]["from"]).to eq("*******1212")
      end
    end

    context "when the viewer is admin" do
      subject(:result) { described_class.call(event:, viewer: :admin) }

      it "still masks sensitive changes" do
        expect(result.data[:projection][:changes]["phone"]["from"]).to eq("*******1212")
      end
    end
  end
end
