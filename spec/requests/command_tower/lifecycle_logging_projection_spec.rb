# frozen_string_literal: true

RSpec.describe "engine HTTP curated lifecycle log projection", type: :request do
  let(:user) { create(:user, roles: ["member"]) }
  let(:headers) { authenticate_request_with_bearer!(user) }
  let(:info_hashes) { [] }
  let(:asn_payloads) { [] }
  let(:subscriber) do
    events = asn_payloads
    ActiveSupport::Notifications.subscribe(/\Acommand_tower\.lifecycle\./) do |_name, _s, _f, _id, payload|
      events << payload.dup
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

  context "when GET /me has a valid Bearer token", :with_rbac_setup do
    before { get "/me", headers: headers }

    let(:workflow_success_logs) do
      info_hashes.select do |message|
        message[:event].to_s == CommandTower::Events::WORKFLOW_COMPLETED &&
          message[:outcome].to_s == "success"
      end
    end
    let(:asn_completed) do
      asn_payloads.find { |payload| payload[:outcome].to_s == "success" && payload[:layer] == :workflow }
    end

    let(:me_workflow_log) do
      workflow_success_logs.find { |message| message[:subject] == "CommandTower::Workflows::Me::ShowWorkflow" }
    end

    it { expect(response).to have_http_status(:ok) }

    it "keeps a rich ASN snapshot" do
      expect(asn_completed).to include(:event_uuid, :layer, :log_lifecycle, :execution_uuid, :correlation_id)
    end

    it "materializes a narrower operational Hash for workflow completion" do
      expect(me_workflow_log).to include(
        :event, :subject, :outcome, :duration_ms, :execution_uuid, :correlation_id, :user_id
      )
      expect(workflow_success_logs.flat_map(&:keys).uniq).not_to include(
        :event_uuid, :layer, :log_lifecycle, :log_level, :source, :causation_id
      )
    end
  end
end
