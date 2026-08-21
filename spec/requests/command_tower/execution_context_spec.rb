# frozen_string_literal: true

RSpec.describe "engine HTTP Execution Context", type: :request do
  let(:captured) { {} }

  before do
    allow(CommandTower).to receive(:with_execution).and_wrap_original do |orig, **kwargs, &block|
      orig.call(**kwargs) do
        result = block.call
        captured.merge!(
          source: CommandTower::Current.source,
          execution_uuid: CommandTower::Current.execution_uuid,
          request_id: CommandTower::Current.request_id,
          correlation_id: CommandTower::Current.correlation_id,
          user_id: CommandTower::Current.user_id,
          effective_user_id: CommandTower::Current.effective_user_id,
          originating_administrator_id: CommandTower::Current.originating_administrator_id,
          impersonation_active: CommandTower::Current.impersonation_active
        )
        result
      end
    end
  end

  context "when GET /auth/identity-policy is unauthenticated" do
    before { get "/auth/identity-policy" }

    it { expect(response).to have_http_status(:ok) }

    it "establishes HTTP context from the Rails request id" do
      expect(captured[:source]).to eq(:http)
      expect(captured[:execution_uuid]).to be_present
      expect(captured[:request_id]).to be_present
      expect(captured[:correlation_id]).to eq(captured[:request_id])
      expect(captured[:request_id]).not_to eq(captured[:execution_uuid])
      expect(captured[:user_id]).to be_nil
    end
  end

  context "when GET /auth/session has a valid Bearer token", :with_rbac_setup do
    let(:user) { create(:user, roles: ["member"]) }
    let(:headers) { authenticate_request_with_bearer!(user) }

    before { get "/auth/session", headers: headers }

    it { expect(response).to have_http_status(:ok) }

    it "enriches the same HTTP context with identity scalars" do
      expect(captured[:execution_uuid]).to be_present
      expect(captured[:user_id]).to eq(user.id)
      expect(captured[:effective_user_id]).to eq(user.id)
      expect(captured[:originating_administrator_id]).to be_nil
      expect(captured[:impersonation_active]).to eq(false)
    end
  end

  context "when an authenticated request is followed by a guest request", :with_rbac_setup do
    let(:user) { create(:user, roles: ["member"]) }
    let(:headers) { authenticate_request_with_bearer!(user) }
    let(:captured_user_ids) { [] }

    before do
      allow(CommandTower).to receive(:with_execution).and_wrap_original do |orig, **kwargs, &block|
        orig.call(**kwargs) do
          result = block.call
          captured_user_ids << CommandTower::Current.user_id
          result
        end
      end
      get "/auth/session", headers: headers
      get "/auth/identity-policy"
    end

    it "does not keep the prior user_id on the guest request" do
      expect(captured_user_ids).to eq([user.id, nil])
    end
  end
end
