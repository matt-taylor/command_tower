# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Messaging::Execution::DeliverWorkflow, :messaging_accept do
  let(:user) { create(:user) }
  let(:communication) do
    create(
      :messaging_communication,
      user:,
      host_event_identity: "exec-#{SecureRandom.hex(4)}",
      accept_request_fingerprint: "fp",
      status: "accepted",
      execution_handoff_status: "enqueued",
    )
  end
  let(:platform_enabled_channels) { %w[email] }
  let!(:destination_plan) do
    create(
      :messaging_destination_plan,
      communication:,
      decision: {
        "selected_channels" => %w[email],
        "inbox_selected" => false,
        "mandatory" => false,
        "platform_enabled_channels" => platform_enabled_channels,
        "excluded_destinations" => [],
      },
    )
  end
  let(:delivery) do
    create(
      :messaging_channel_delivery,
      communication:,
      channel_key: "email",
      status: "queued",
      execution_attempt_count: 0,
    )
  end

  let(:success_adapter) do
    CommandTower::Messaging::Execution::Adapters::FakeAdapter.new(outcome: :success)
  end

  let(:enable_sms_platform!) do
    destination_plan.update!(
      decision: destination_plan.decision.merge(
        "platform_enabled_channels" => %w[email sms],
        "selected_channels" => %w[sms],
      ),
    )
    allow(
      CommandTower::Messaging::Execution::Adapters::Sms::Configuration,
    ).to receive(:sms_configured?).and_return(true)
  end

  context "when the delivery is planned" do
    before { delivery.update!(status: "planned") }

    subject(:invoke) do
      described_class.call(channel_delivery_id: delivery.id, executor: success_adapter)
    end

    before { invoke }

    it "does not execute planned deliveries" do
      expect(delivery.reload.status).to eq("planned")
      expect(delivery.execution_attempt_count).to eq(0)
      expect(CommandTower::Messaging::DeliveryAttempt.count).to eq(0)
    end
  end

  context "when queued work succeeds" do
    subject(:invoke) do
      described_class.call(channel_delivery_id: delivery.id, executor: success_adapter)
    end

    before { invoke }

    it "claims queued work, writes an attempt, and marks accepted_by_provider on success" do
      expect(delivery.reload.status).to eq("accepted_by_provider")
      expect(delivery.execution_attempt_count).to eq(1)
      expect(delivery.execution_claimed_at).to be_present
      expect(delivery.delivery_attempts.sole.status).to eq("succeeded")
      expect(delivery.delivery_attempts.sole.finished_at).to be_present
    end
  end

  context "when the adapter returns retryable failure" do
    let(:adapter) do
      CommandTower::Messaging::Execution::Adapters::FakeAdapter.new(
        outcome: :retryable_failure,
        error_code: "provider_timeout",
      )
    end

    subject(:invoke) { described_class.call(channel_delivery_id: delivery.id, executor: adapter) }

    before { invoke }

    it "maps retryable adapter failure to matched attempt and delivery statuses" do
      expect(delivery.reload.status).to eq("failed_retryable")
      expect(delivery.delivery_attempts.sole.status).to eq("failed_retryable")
      expect(delivery.delivery_attempts.sole.error_code).to eq("provider_timeout")
    end
  end

  context "when the adapter returns terminal failure" do
    let(:adapter) do
      CommandTower::Messaging::Execution::Adapters::FakeAdapter.new(
        outcome: :terminal_failure,
        error_code: "invalid_recipient",
      )
    end

    subject(:invoke) { described_class.call(channel_delivery_id: delivery.id, executor: adapter) }

    before { invoke }

    it "maps terminal adapter failure to matched attempt and delivery statuses" do
      expect(delivery.reload.status).to eq("failed_terminal")
      expect(delivery.delivery_attempts.sole.status).to eq("failed_terminal")
    end
  end

  context "when no executor is injected under :test delivery" do
    around do |example|
      previous_fake = CommandTower.config.messaging.allow_fake_adapter
      CommandTower.config.messaging.allow_fake_adapter = false
      example.run
    ensure
      CommandTower.config.messaging.allow_fake_adapter = previous_fake
    end

    before do
      ActionMailer::Base.deliveries.clear
      communication.update!(metadata: { "deep_link" => "https://example.com/go" })
    end

    subject(:invoke) { described_class.call(channel_delivery_id: delivery.id) }

    before { invoke }

    it "uses EmailAdapter under :test delivery when no executor is injected" do
      expect(delivery.reload.status).to eq("accepted_by_provider")
      expect(delivery.delivery_attempts.sole.status).to eq("succeeded")
      expect(delivery.delivery_attempts.sole.normalized_provider_status).to eq("accepted")
      expect(ActionMailer::Base.deliveries.size).to eq(1)
      expect(ActionMailer::Base.deliveries.last.to).to eq([user.email])
      expect(ActionMailer::Base.deliveries.last.text_part.body.to_s).to include("https://example.com/go")
      expect(ActionMailer::Base.deliveries.last.html_part.body.to_s).to include("https://example.com/go")
      expect(CommandTower::Messaging::DeliveryAttempt.column_names).not_to include(
        "rendered_html", "rendered_text", "subject", "html_body", "text_body",
      )
      expect(delivery.delivery_attempts.sole.attributes.values.join).not_to include(communication.body)
    end
  end

  context "when :smtp contract is incomplete" do
    around do |example|
      previous_fake = CommandTower.config.messaging.allow_fake_adapter
      previous_method = CommandTower.config.email.delivery_method
      previous_settings = Rails.configuration.action_mailer.smtp_settings.dup
      CommandTower.config.messaging.allow_fake_adapter = false
      CommandTower.config.email.delivery_method = :smtp
      Rails.configuration.action_mailer.smtp_settings = previous_settings.merge(
        address: "smtp.example.com",
        port: 587,
        user_name: "",
        password: "",
        authentication: "plain",
        enable_starttls_auto: true,
      )
      example.run
    ensure
      CommandTower.config.messaging.allow_fake_adapter = previous_fake
      CommandTower.config.email.delivery_method = previous_method
      Rails.configuration.action_mailer.smtp_settings = previous_settings
    end

    before { ActionMailer::Base.deliveries.clear }

    subject(:invoke) { described_class.call(channel_delivery_id: delivery.id) }

    before { invoke }

    it "fails closed with UnconfiguredAdapter when :smtp contract is incomplete" do
      expect(delivery.reload.status).to eq("failed_terminal")
      expect(delivery.delivery_attempts.sole.status).to eq("failed_terminal")
      expect(delivery.delivery_attempts.sole.error_code).to eq("adapter_unconfigured")
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  context "when allow_fake_adapter is enabled" do
    around do |example|
      previous = CommandTower.config.messaging.allow_fake_adapter
      CommandTower.config.messaging.allow_fake_adapter = true
      example.run
    ensure
      CommandTower.config.messaging.allow_fake_adapter = previous
    end

    before { ActionMailer::Base.deliveries.clear }

    subject(:invoke) { described_class.call(channel_delivery_id: delivery.id) }

    before { invoke }

    it "uses FakeAdapter when allow_fake_adapter is enabled" do
      expect(delivery.reload.status).to eq("accepted_by_provider")
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  context "when allow_fake_adapter is false and MESSAGING_ALLOW_FAKE_ADAPTER ENV is true" do
    around do |example|
      previous = CommandTower.config.messaging.allow_fake_adapter
      previous_env = ENV["MESSAGING_ALLOW_FAKE_ADAPTER"]
      CommandTower.config.messaging.allow_fake_adapter = false
      ENV["MESSAGING_ALLOW_FAKE_ADAPTER"] = "true"
      example.run
    ensure
      CommandTower.config.messaging.allow_fake_adapter = previous
      ENV["MESSAGING_ALLOW_FAKE_ADAPTER"] = previous_env
    end

    before { ActionMailer::Base.deliveries.clear }

    subject(:invoke) { described_class.call(channel_delivery_id: delivery.id) }

    before { invoke }

    it "ignores MESSAGING_ALLOW_FAKE_ADAPTER ENV when allow_fake_adapter is false" do
      expect(delivery.reload.status).to eq("accepted_by_provider")
      expect(ActionMailer::Base.deliveries.size).to eq(1)
    end
  end

  context "when an executor is injected with allow_fake_adapter enabled" do
    around do |example|
      previous = CommandTower.config.messaging.allow_fake_adapter
      CommandTower.config.messaging.allow_fake_adapter = true
      example.run
    ensure
      CommandTower.config.messaging.allow_fake_adapter = previous
    end

    let(:adapter) do
      CommandTower::Messaging::Execution::Adapters::FakeAdapter.new(
        outcome: :terminal_failure,
        error_code: "injected",
      )
    end

    subject(:invoke) { described_class.call(channel_delivery_id: delivery.id, executor: adapter) }

    before { invoke }

    it "prefers an injected executor over EmailAdapter and FakeAdapter" do
      expect(delivery.reload.status).to eq("failed_terminal")
      expect(delivery.delivery_attempts.sole.error_code).to eq("injected")
    end
  end

  context "when the adapter raises an unexpected exception" do
    let(:adapter) { instance_double(CommandTower::Messaging::Execution::Adapters::FakeAdapter) }

    before { allow(adapter).to receive(:call).and_raise(RuntimeError, "secret boom details") }

    subject(:invoke) { described_class.call(channel_delivery_id: delivery.id, executor: adapter) }

    it "maps unexpected exceptions to internal_adapter_error with matched statuses" do
      expect { invoke }.not_to raise_error
      expect(delivery.reload.status).to eq("failed_retryable")
      expect(delivery.delivery_attempts.sole.status).to eq("failed_retryable")
      expect(delivery.delivery_attempts.sole.error_code).to eq("internal_adapter_error")
      expect(delivery.delivery_attempts.sole.error_class).to eq("RuntimeError")
      expect(delivery.delivery_attempts.sole.attributes.values.join).not_to include("secret boom details")
    end
  end

  context "when the adapter returns something other than an AdapterResult" do
    let(:adapter) { instance_double(CommandTower::Messaging::Execution::Adapters::FakeAdapter) }

    before { allow(adapter).to receive(:call).and_return(true) }

    subject(:invoke) { described_class.call(channel_delivery_id: delivery.id, executor: adapter) }

    before { invoke }

    it "treats non-AdapterResult returns as unexpected failure" do
      expect(delivery.reload.status).to eq("failed_retryable")
      expect(delivery.delivery_attempts.sole.status).to eq("failed_retryable")
      expect(delivery.delivery_attempts.sole.error_code).to eq("internal_adapter_error")
    end
  end

  context "when attempt creation fails" do
    let(:adapter) { instance_double(CommandTower::Messaging::Execution::Adapters::FakeAdapter) }

    before do
      allow(adapter).to receive(:call)
      allow(CommandTower::Messaging::DeliveryAttempt).to receive(:create!).and_raise(
        ActiveRecord::StatementInvalid.new("insert failed"),
      )
    end

    subject(:invoke) { described_class.call(channel_delivery_id: delivery.id, executor: adapter) }

    before { invoke }

    it "does not call the adapter when attempt creation fails" do
      expect(adapter).not_to have_received(:call)
      expect(delivery.reload.status).to eq("failed_retryable")
      expect(CommandTower::Messaging::DeliveryAttempt.count).to eq(0)
    end
  end

  context "after retryable failure" do
    before do
      failure = CommandTower::Messaging::Execution::Adapters::FakeAdapter.new(outcome: :retryable_failure)
      described_class.call(channel_delivery_id: delivery.id, executor: failure)
    end

    subject(:second_run) do
      described_class.call(channel_delivery_id: delivery.id, executor: success_adapter)
    end

    it "does not allow an immediate re-run to bypass Recovery after retryable failure" do
      expect(delivery.reload.status).to eq("failed_retryable")
      second_run
      expect(delivery.reload.status).to eq("failed_retryable")
      expect(delivery.delivery_attempts.count).to eq(1)
    end
  end

  context "when the delivery is already accepted_by_provider" do
    let(:adapter) { instance_double(CommandTower::Messaging::Execution::Adapters::FakeAdapter) }

    before do
      delivery.update!(status: "accepted_by_provider", execution_attempt_count: 1)
      allow(adapter).to receive(:call)
    end

    subject(:invoke) { described_class.call(channel_delivery_id: delivery.id, executor: adapter) }

    before { invoke }

    it "is a no-op when already accepted_by_provider" do
      expect(adapter).not_to have_received(:call)
      expect(delivery.reload.status).to eq("accepted_by_provider")
    end
  end

  context "under concurrent workers" do
    let(:barrier) { Queue.new }
    let(:results) { Queue.new }

    before do
      threads = Array.new(2) do
        Thread.new do
          barrier.pop
          results << described_class.call(
            channel_delivery_id: delivery.id,
            executor: CommandTower::Messaging::Execution::Adapters::FakeAdapter.new,
          )
        end
      end

      2.times { barrier << :go }
      threads.each(&:join)
    end

    it "prevents duplicate claims under concurrent workers" do
      expect(delivery.reload.status).to eq("accepted_by_provider")
      expect(delivery.execution_attempt_count).to eq(1)
      expect(delivery.delivery_attempts.count).to eq(1)
    end
  end

  context "when the SMS adapter is disabled after readiness resolves the channel" do
    around do |example|
      previous_fake = CommandTower.config.messaging.allow_fake_adapter
      CommandTower.config.messaging.allow_fake_adapter = false
      example.run
    ensure
      CommandTower.config.messaging.allow_fake_adapter = previous_fake
      CommandTower.config.messaging.sms.adapter = "disabled"
    end

    before do
      allow(
        CommandTower::Messaging::Execution::Adapters::Sms::Configuration,
      ).to receive(:sms_configured?).and_call_original
      user.update!(phone_number: "+14155552671", phone_number_validated: true)
      delivery.update!(channel_key: "sms")
      destination_plan.update!(
        decision: destination_plan.decision.merge(
          "platform_enabled_channels" => %w[email sms],
          "selected_channels" => %w[sms],
        ),
      )
      CommandTower.config.messaging.sms.adapter = "disabled"
    end

    subject(:invoke) { described_class.call(channel_delivery_id: delivery.id) }

    before { invoke }

    it "finalizes disabled SMS adapter as adapter_unconfigured after readiness fails platform_configured" do
      expect(delivery.reload.status).to eq("failed_terminal")
      expect(delivery.delivery_attempts.sole.status).to eq("failed_terminal")
      expect(delivery.delivery_attempts.sole.error_code).to eq("adapter_unconfigured")
    end
  end

  context "when SMS is ready and FakeAdapter succeeds" do
    let(:adapter) { CommandTower::Messaging::Execution::Adapters::FakeAdapter.new(outcome: :success) }

    before do
      enable_sms_platform!
      user.update!(phone_number: "+14155552671", phone_number_validated: true)
      delivery.update!(channel_key: "sms")
    end

    subject(:invoke) { described_class.call(channel_delivery_id: delivery.id, executor: adapter) }

    before { invoke }

    it "resolves verified Identity phone for SMS and persists FakeAdapter success" do
      expect(delivery.reload.status).to eq("accepted_by_provider")
      expect(delivery.delivery_attempts.sole.status).to eq("succeeded")
      expect(adapter.last_request.channel_key).to eq("sms")
      expect(adapter.last_request.rendered).to be_a(CommandTower::Messaging::Rendering::RenderedSmsPayload)
      expect(adapter.last_request.rendered.recipient_address).to eq("+14155552671")
      expect(adapter.last_request.rendered.body).to be_present
    end
  end

  context "when the adapter must not be invoked because readiness resolution fails" do
    let(:adapter) { instance_double(CommandTower::Messaging::Execution::Adapters::FakeAdapter) }

    before { allow(adapter).to receive(:call) }

    context "when SMS phone is unverified" do
      before do
        enable_sms_platform!
        user.update!(phone_number: "+14155552671", phone_number_validated: false)
        delivery.update!(channel_key: "sms")
      end

      subject(:invoke) { described_class.call(channel_delivery_id: delivery.id, executor: adapter) }

      before { invoke }

      it "finalizes unverified SMS phone as recipient_unverified without calling the adapter" do
        expect(delivery.reload.status).to eq("failed_terminal")
        expect(delivery.delivery_attempts.sole.error_code).to eq("recipient_unverified")
        expect(adapter).not_to have_received(:call)
      end
    end

    context "when SMS phone is missing" do
      before do
        enable_sms_platform!
        user.update!(phone_number: nil, phone_number_validated: false)
        delivery.update!(channel_key: "sms")
      end

      subject(:invoke) { described_class.call(channel_delivery_id: delivery.id, executor: adapter) }

      before { invoke }

      it "finalizes missing SMS phone as recipient_missing without calling the adapter" do
        expect(delivery.reload.status).to eq("failed_terminal")
        expect(delivery.delivery_attempts.sole.error_code).to eq("recipient_missing")
        expect(adapter).not_to have_received(:call)
      end
    end

    context "when Accept-time enablement no longer includes the channel" do
      before do
        enable_sms_platform!
        user.update!(phone_number: "+14155552671", phone_number_validated: true)
        delivery.update!(channel_key: "sms")
        destination_plan.update!(
          decision: destination_plan.decision.merge("platform_enabled_channels" => %w[email]),
        )
      end

      subject(:invoke) { described_class.call(channel_delivery_id: delivery.id, executor: adapter) }

      before { invoke }

      it "finalizes platform_disabled when Accept-time enablement no longer includes the channel" do
        expect(delivery.reload.status).to eq("failed_terminal")
        expect(delivery.delivery_attempts.sole.error_code).to eq("platform_disabled")
        expect(adapter).not_to have_received(:call)
      end
    end

    context "when email_validated regresses" do
      before { user.update!(email_validated: false) }

      subject(:invoke) { described_class.call(channel_delivery_id: delivery.id, executor: adapter) }

      before { invoke }

      it "finalizes email_validated regression as recipient_unverified" do
        expect(delivery.reload.status).to eq("failed_terminal")
        expect(delivery.delivery_attempts.sole.error_code).to eq("recipient_unverified")
        expect(adapter).not_to have_received(:call)
      end
    end
  end

  context "when the recipient is missing at render time" do
    let(:adapter) { instance_double(CommandTower::Messaging::Execution::Adapters::FakeAdapter) }

    before do
      allow(adapter).to receive(:call)
      allow(CommandTower::Messaging::Rendering::ChannelRenderer).to receive(:render)
      user.update!(email: "")
      ActionMailer::Base.deliveries.clear
    end

    subject(:invoke) { described_class.call(channel_delivery_id: delivery.id, executor: adapter) }

    before { invoke }

    it "finalizes missing recipients as recipient_missing without calling the adapter" do
      expect(delivery.reload.status).to eq("failed_terminal")
      expect(delivery.delivery_attempts.sole.status).to eq("failed_terminal")
      expect(delivery.delivery_attempts.sole.error_code).to eq("recipient_missing")
      expect(CommandTower::Messaging::Rendering::ChannelRenderer).not_to have_received(:render)
      expect(adapter).not_to have_received(:call)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  context "when template rendering fails" do
    let(:adapter) { instance_double(CommandTower::Messaging::Execution::Adapters::FakeAdapter) }

    before do
      allow(adapter).to receive(:call)
      allow(CommandTower::Messaging::Rendering::ChannelRenderer).to receive(:render).and_raise(
        CommandTower::Messaging::Rendering::RenderError.new(code: "render_failed", error_class: "Errno::ENOENT"),
      )
      ActionMailer::Base.deliveries.clear
    end

    subject(:invoke) { described_class.call(channel_delivery_id: delivery.id, executor: adapter) }

    before { invoke }

    it "finalizes template failures as render_failed without calling the adapter" do
      expect(delivery.reload.status).to eq("failed_terminal")
      expect(delivery.delivery_attempts.sole.status).to eq("failed_terminal")
      expect(delivery.delivery_attempts.sole.error_code).to eq("render_failed")
      expect(adapter).not_to have_received(:call)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  context "when EmailAdapter reports a retryable transport failure" do
    let(:adapter) { instance_double(CommandTower::Messaging::Execution::Adapters::Email::Adapter) }

    before do
      allow(adapter).to receive(:call).and_return(
        CommandTower::Messaging::Execution::AdapterResult.build(
          outcome: :retryable_failure,
          error_code: "smtp_transient",
        ),
      )
    end

    subject(:invoke) { described_class.call(channel_delivery_id: delivery.id, executor: adapter) }

    before { invoke }

    it "maps EmailAdapter retryable transport failures to matched retryable statuses" do
      expect(delivery.reload.status).to eq("failed_retryable")
      expect(delivery.delivery_attempts.sole.status).to eq("failed_retryable")
      expect(delivery.delivery_attempts.sole.error_code).to eq("smtp_transient")
    end
  end

  context "when EmailAdapter reports a terminal transport failure" do
    let(:adapter) { instance_double(CommandTower::Messaging::Execution::Adapters::Email::Adapter) }

    before do
      allow(adapter).to receive(:call).and_return(
        CommandTower::Messaging::Execution::AdapterResult.build(
          outcome: :terminal_failure,
          error_code: "smtp_rejected",
        ),
      )
    end

    subject(:invoke) { described_class.call(channel_delivery_id: delivery.id, executor: adapter) }

    before { invoke }

    it "maps EmailAdapter terminal transport failures to matched terminal statuses" do
      expect(delivery.reload.status).to eq("failed_terminal")
      expect(delivery.delivery_attempts.sole.status).to eq("failed_terminal")
      expect(delivery.delivery_attempts.sole.error_code).to eq("smtp_rejected")
    end
  end

  context "when the workflow renders before invoking the adapter" do
    let(:adapter) { instance_double(CommandTower::Messaging::Execution::Adapters::FakeAdapter) }

    before do
      allow(adapter).to receive(:call) do |request:|
        expect(request).to be_a(CommandTower::Messaging::Execution::AdapterRequest)
        expect(request.rendered).to be_a(CommandTower::Messaging::Rendering::RenderedPayload)
        expect(request.rendered.recipient_address).to eq(user.email)
        CommandTower::Messaging::Execution::AdapterResult.build(outcome: :success)
      end
    end

    subject(:invoke) { described_class.call(channel_delivery_id: delivery.id, executor: adapter) }

    before { invoke }

    it "renders before invoking the adapter and does not persist rendered bodies" do
      expect(adapter).to have_received(:call)
      expect(delivery.reload.status).to eq("accepted_by_provider")
      expect(CommandTower::Messaging::DeliveryAttempt.column_names).not_to include("rendered_html")
      expect(CommandTower::Messaging::ChannelDelivery.column_names).not_to include("rendered_html")
    end
  end

  context "pushover handoff boundary" do
    let(:platform_enabled_channels) { %w[pushover] }
    let(:endpoint) do
      view = CommandTower::Messaging::Endpoints.create(
        owner_user_id: user.id,
        channel_key: "pushover",
        credentials: {
          user_key: "u" + ("c" * 30),
          application_token: "t" + ("d" * 30),
        },
      )
      record = CommandTower::Messaging::Endpoint.find(view.id)
      record.update!(verification_state: "verified", verified_at: Time.current)
      record
    end

    around do |example|
      previous = CommandTower.config.messaging.pushover.adapter
      previous_fake = CommandTower.config.messaging.allow_fake_adapter
      CommandTower.config.messaging.pushover.adapter = "fake"
      # Real Pushover::Adapter must run — platform FakeAdapter succeeds without provider status.
      CommandTower.config.messaging.allow_fake_adapter = false
      CommandTower::Messaging::Pushover::Transport.reset_adapter!
      CommandTower::Messaging::Pushover::Adapters::FakeAdapter.reset!
      example.run
    ensure
      CommandTower.config.messaging.pushover.adapter = previous
      CommandTower.config.messaging.allow_fake_adapter = previous_fake
      CommandTower::Messaging::Pushover::Transport.reset_adapter!
      CommandTower::Messaging::Pushover::Adapters::FakeAdapter.reset!
    end

    before do
      endpoint
      delivery.update!(channel_key: "pushover")
      destination_plan.update!(
        decision: destination_plan.decision.merge(
          "selected_channels" => %w[pushover],
          "platform_enabled_channels" => platform_enabled_channels,
        ),
      )
    end

    context "when delivering via readiness resolved_endpoint_id" do
      subject(:invoke) { described_class.call(channel_delivery_id: delivery.id) }

      before { invoke }

      it "delivers an explicitly handed-off Pushover ChannelDelivery via readiness resolved_endpoint_id" do
        expect(delivery.reload.status).to eq("accepted_by_provider")
        expect(delivery.delivery_attempts.sole.status).to eq("succeeded")
        expect(delivery.delivery_attempts.sole.normalized_provider_status).to eq("accepted")
        expect(delivery.delivery_attempts.sole.provider_message_id).to be_present
        expect(CommandTower::Messaging::Pushover::Adapters::FakeAdapter.messages.size).to eq(1)
      end
    end

    context "when endpoint is revoked after handoff (TOCTOU)" do
      before { endpoint.update!(lifecycle_state: "revoked", revoked_at: Time.current) }

      subject(:invoke) { described_class.call(channel_delivery_id: delivery.id) }

      before { invoke }

      it "terminals without calling Transport when endpoint is revoked after handoff (TOCTOU)" do
        expect(delivery.reload.status).to eq("failed_terminal")
        expect(delivery.delivery_attempts.sole.status).to eq("failed_terminal")
        expect(CommandTower::Messaging::Pushover::Adapters::FakeAdapter.messages).to be_empty
      end
    end

    context "when verification is reset after handoff" do
      before { endpoint.update!(verification_state: "unverified", verified_at: nil) }

      subject(:invoke) { described_class.call(channel_delivery_id: delivery.id) }

      before { invoke }

      it "terminals without Transport when verification is reset after handoff" do
        expect(delivery.reload.status).to eq("failed_terminal")
        expect(CommandTower::Messaging::Pushover::Adapters::FakeAdapter.messages).to be_empty
      end
    end

    context "when adapter is disabled after handoff" do
      before do
        CommandTower.config.messaging.pushover.adapter = "disabled"
        CommandTower::Messaging::Pushover::Transport.reset_adapter!
      end

      subject(:invoke) { described_class.call(channel_delivery_id: delivery.id) }

      before { invoke }

      it "terminals when adapter is disabled after handoff" do
        expect(delivery.reload.status).to eq("failed_terminal")
        expect(delivery.delivery_attempts.sole.error_code).to eq("adapter_unconfigured")
        expect(CommandTower::Messaging::Pushover::Adapters::FakeAdapter.messages).to be_empty
      end
    end

    context "when the rendered payload is inspected for secrets" do
      let(:adapter) { instance_double(CommandTower::Messaging::Execution::Adapters::FakeAdapter) }

      before do
        allow(adapter).to receive(:call) do |request:|
          expect(request.rendered).to be_a(CommandTower::Messaging::Rendering::RenderedPushoverPayload)
          expect(request.rendered.recipient_address).to eq(endpoint.id.to_s)
          expect(request.rendered.to_h.values.join).not_to include("cccccccccc")
          CommandTower::Messaging::Execution::AdapterResult.build(outcome: :success)
        end
      end

      subject(:invoke) { described_class.call(channel_delivery_id: delivery.id, executor: adapter) }

      before { invoke }

      it "passes opaque endpoint id into the rendered payload without secrets" do
        expect(adapter).to have_received(:call)
      end
    end
  end
end
