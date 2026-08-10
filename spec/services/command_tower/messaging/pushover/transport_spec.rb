# frozen_string_literal: true

require "json"
require "net/http"

RSpec.describe CommandTower::Messaging::Pushover::Transport do
  around do |example|
    previous_adapter = CommandTower.config.messaging.pushover.adapter
    previous_injected = described_class.instance_variable_get(:@adapter)
    CommandTower::Messaging::Pushover::Adapters::FakeAdapter.reset!
    described_class.reset_adapter!
    example.run
  ensure
    CommandTower.config.messaging.pushover.adapter = previous_adapter
    described_class.instance_variable_set(:@adapter, previous_injected)
    CommandTower::Messaging::Pushover::Adapters::FakeAdapter.reset!
  end

  describe "fake adapter" do
    before { CommandTower.config.messaging.pushover.adapter = "fake" }

    context "when validating a user" do
      subject(:result) do
        described_class.validate_user!(
          user_key: "secret-user-key",
          application_token: "secret-app-token",
        )
      end

      it "validates and records safe metadata without secrets" do
        expect(result.success?).to be(true)
        expect(CommandTower::Messaging::Pushover::Adapters::FakeAdapter.validations.last).to eq(
          user_key_present: true, application_token_present: true,
        )
        expect(CommandTower::Messaging::Pushover::Adapters::FakeAdapter.validations.last.to_s).not_to include("secret-user-key")
        expect(CommandTower::Messaging::Pushover::Adapters::FakeAdapter.validations.last.to_s).not_to include("secret-app-token")
      end
    end

    context "when FakeAdapter injects invalid_user" do
      before { CommandTower::Messaging::Pushover::Adapters::FakeAdapter.fail_with = :invalid_user }

      subject(:result) { described_class.validate_user!(user_key: "u", application_token: "t") }

      it "returns invalid_user" do
        expect(result.error_code).to eq(:invalid_user)
      end
    end

    context "when FakeAdapter injects timeout on send_test_notification!" do
      before { CommandTower::Messaging::Pushover::Adapters::FakeAdapter.fail_with = :timeout }

      subject(:result) do
        described_class.send_test_notification!(
          user_key: "u", application_token: "t", title: "t", message: "m",
        )
      end

      it "returns timeout" do
        expect(result.error_code).to eq(:timeout)
      end
    end

    context "when FakeAdapter injects provider_unavailable" do
      before { CommandTower::Messaging::Pushover::Adapters::FakeAdapter.fail_with = :provider_unavailable }

      subject(:result) { described_class.validate_user!(user_key: "u", application_token: "t") }

      it "returns provider_unavailable" do
        expect(result.error_code).to eq(:provider_unavailable)
      end
    end
  end

  describe "log adapter" do
    before { CommandTower.config.messaging.pushover.adapter = "log" }

    context "when validate_user! logs" do
      let(:logged) { [] }

      before { allow(Rails.logger).to receive(:info) { |msg| logged << msg.to_s } }

      subject(:result) do
        described_class.validate_user!(user_key: "secret-user", application_token: "secret-token")
      end

      it "succeeds without network and logs lengths only" do
        expect(result.success?).to be(true)
        expect(logged.join).not_to include("secret-user")
        expect(logged.join).not_to include("secret-token")
        expect(logged.join).to include("messaging.pushover.log_adapter.validate_user")
      end
    end
  end

  describe "disabled adapter" do
    before { CommandTower.config.messaging.pushover.adapter = "disabled" }

    context "when validating a user" do
      subject(:result) { described_class.validate_user!(user_key: "u", application_token: "t") }

      it "fails closed" do
        expect(result.success?).to be(false)
        expect(result.error_code).to eq(:adapter_disabled)
      end
    end

    context "when sending a production message" do
      subject(:result) do
        described_class.send_message!(
          user_key: "u", application_token: "t", title: "t", message: "m",
        )
      end

      it "fails closed" do
        expect(result.success?).to be(false)
        expect(result.error_code).to eq(:adapter_disabled)
      end
    end
  end

  describe "send_message!" do
    before { CommandTower.config.messaging.pushover.adapter = "fake" }

    context "when sending a message" do
      subject(:result) do
        described_class.send_message!(
          user_key: "secret-user-key",
          application_token: "secret-app-token",
          title: "Hello",
          message: "World",
        )
      end

      it "records safe metadata and returns a provider_request_id without secrets" do
        expect(result.success?).to be(true)
        expect(result.provider_request_id).to be_present
        expect(CommandTower::Messaging::Pushover::Adapters::FakeAdapter.messages.last[:title]).to eq("Hello")
        expect(CommandTower::Messaging::Pushover::Adapters::FakeAdapter.messages.last.to_s).not_to include("secret-user-key")
        expect(CommandTower::Messaging::Pushover::Adapters::FakeAdapter.messages.last.to_s).not_to include("secret-app-token")
      end
    end

    context "when FakeAdapter injects invalid_credentials" do
      before { CommandTower::Messaging::Pushover::Adapters::FakeAdapter.fail_with = :invalid_credentials }

      subject(:result) do
        described_class.send_message!(
          user_key: "u", application_token: "t", title: "t", message: "m",
        )
      end

      it "returns invalid_credentials" do
        expect(result.error_code).to eq(:invalid_credentials)
      end
    end

    context "when FakeAdapter injects rate_limited" do
      before { CommandTower::Messaging::Pushover::Adapters::FakeAdapter.fail_with = :rate_limited }

      subject(:result) do
        described_class.send_message!(
          user_key: "u", application_token: "t", title: "t", message: "m",
        )
      end

      it "returns rate_limited" do
        expect(result.error_code).to eq(:rate_limited)
      end
    end
  end

  describe "log adapter send_message!" do
    before { CommandTower.config.messaging.pushover.adapter = "log" }

    context "when send_message! logs" do
      let(:logged) { [] }

      before { allow(Rails.logger).to receive(:info) { |msg| logged << msg.to_s } }

      subject(:result) do
        described_class.send_message!(
          user_key: "secret-user", application_token: "secret-token", title: "t", message: "m",
        )
      end

      it "succeeds with safe log metadata only" do
        expect(result.success?).to be(true)
        expect(logged.join).not_to include("secret-user")
        expect(logged.join).to include("messaging.pushover.log_adapter.send_message")
      end
    end
  end

  describe "http adapter" do
    before { CommandTower.config.messaging.pushover.adapter = "http" }

    context "when the provider responds successfully to validate" do
      let(:response) { instance_double(Net::HTTPOK, code: "200", body: { status: 1 }.to_json, is_a?: true) }

      before do
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(Net::HTTP).to receive(:start).and_return(response)
      end

      subject(:result) { described_class.validate_user!(user_key: "u", application_token: "t") }

      it "classifies successful validate responses" do
        expect(result.success?).to be(true)
      end
    end

    context "when the provider reports an invalid user" do
      let(:response) do
        instance_double(
          Net::HTTPBadRequest,
          code: "400",
          body: { status: 0, errors: ["user key is invalid"] }.to_json,
        )
      end

      before do
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
        allow(Net::HTTP).to receive(:start).and_return(response)
      end

      subject(:result) do
        described_class.validate_user!(user_key: "secret-user", application_token: "secret-token")
      end

      it "classifies invalid user errors without leaking secrets" do
        expect(result.success?).to be(false)
        expect(result.error_code).to eq(:invalid_user)
        expect(result.error_message).not_to include("secret-user")
        expect(result.error_message).not_to include("secret-token")
      end
    end

    context "when the network call times out" do
      before { allow(Net::HTTP).to receive(:start).and_raise(Net::ReadTimeout) }

      subject(:result) do
        described_class.send_test_notification!(
          user_key: "u", application_token: "t", title: "t", message: "m",
        )
      end

      it "maps timeouts" do
        expect(result.error_code).to eq(:timeout)
      end
    end

    context "when send_message! succeeds and returns a request id" do
      let(:response) do
        instance_double(
          Net::HTTPOK,
          code: "200",
          body: { status: 1, request: "req-abc-123" }.to_json,
        )
      end

      before do
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(Net::HTTP).to receive(:start).and_return(response)
      end

      subject(:result) do
        described_class.send_message!(
          user_key: "u", application_token: "t", title: "Hello", message: "World",
        )
      end

      it "captures provider request id on successful send_message!" do
        expect(result.success?).to be(true)
        expect(result.provider_request_id).to eq("req-abc-123")
      end
    end

    context "when send_message! is rate limited" do
      let(:response) do
        instance_double(
          Net::HTTPTooManyRequests,
          code: "429",
          body: { status: 0, errors: ["rate limited"] }.to_json,
        )
      end

      before do
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
        allow(Net::HTTP).to receive(:start).and_return(response)
      end

      subject(:result) do
        described_class.send_message!(
          user_key: "u", application_token: "t", title: "t", message: "m",
        )
      end

      it "classifies rate limits as rate_limited" do
        expect(result.error_code).to eq(:rate_limited)
      end
    end
  end
end
