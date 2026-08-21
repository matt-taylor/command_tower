# frozen_string_literal: true

RSpec.describe "engine HTTP lifecycle log materialization", type: :request do
  let(:user) { create(:user, roles: ["member"]) }
  let(:headers) { authenticate_request_with_bearer!(user) }
  let(:info_hashes) { [] }
  let(:recorded) { [] }
  let(:subscriber) do
    events = recorded
    ActiveSupport::Notifications.subscribe(/\Acommand_tower\.lifecycle\./) do |name, *_rest|
      events << name
    end
  end

  before do
    subscriber
    allow(Rails.logger).to receive(:info).and_wrap_original do |method, *args, &block|
      message = args.first
      info_hashes << message if message.is_a?(Hash)
      method.call(*args, &block)
    end
  end

  after { unsubscribe_notifications(subscriber) }

  context "when GET /auth/session has a valid Bearer token", :with_rbac_setup do
    before { get "/auth/session", headers: headers }

    it { expect(response).to have_http_status(:ok) }

    let(:started_count) { recorded.count { |name| name.end_with?(".started") } }
    let(:completed_count) { recorded.count { |name| name.end_with?(".completed") } }
    let(:workflow_success_completions) do
      info_hashes.select do |message|
        message[:event].to_s == CommandTower::Events::WORKFLOW_COMPLETED &&
          message[:outcome].to_s == "success"
      end
    end
    let(:service_success_completions) do
      info_hashes.select do |message|
        message[:event].to_s == CommandTower::Events::SERVICE_COMPLETED &&
          message[:outcome].to_s == "success"
      end
    end
    let(:authorization_info) do
      info_hashes.select do |message|
        message[:event] == "command_tower.log.info" &&
          message[:message].to_s.match?(/User Roles|Authorized:\[true\]/)
      end
    end

    it "still emits started and completed lifecycle pairs" do
      expect(started_count).to be > 0
      expect(started_count).to eq(completed_count)
      expect(recorded).to include(
        CommandTower::Events::WORKFLOW_STARTED,
        CommandTower::Events::WORKFLOW_COMPLETED
      )
    end

    it "materializes successful workflow completions at info and not nested service successes" do
      expect(workflow_success_completions).not_to eq([])
      expect(service_success_completions).to eq([])
    end

    it "does not materialize authorization success diagnostics at info" do
      expect(authorization_info).to eq([])
    end
  end
end
