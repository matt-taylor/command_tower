# frozen_string_literal: true

# Compliance footer and RFC 8058 headers on defined-type email (E-01, E-02, E-03, E-05, E-06, E-11).
RSpec.describe CommandTower::Messaging::Rendering::ChannelRenderer,
               :aggregate_failures, :compliance_render, :defined_render, :messaging_notification_types do
  let(:api_base_url) { "https://api.example.test" }
  let(:preferences_path) { "/settings/notifications" }
  let(:promotional) { false }
  let(:declaration_overrides) { {} }
  let(:communication) do
    build(
      :messaging_communication,
      id: 77, user_id: 4242, notification_type_key: "defined.render", title: "Generic title", body: "Generic body",
      metadata: { "headline" => "Check in is open", "class_name" => "Arms", "deep_link_path" => "/schedule" },
      metadata_version: 1, render_zone: "America/Los_Angeles",
      slots: { "headline" => "Check in is open", "subject" => "Your class is open" }
    )
  end

  around do |example|
    previous = %i[api_base_url preferences_path postal_address].index_with { |key| compliance.public_send(key) }
    compliance.api_base_url = api_base_url
    compliance.preferences_path = preferences_path
    compliance.postal_address = postal_address
    example.run
  ensure
    previous.each { |key, value| compliance.public_send(:"#{key}=", value) }
  end

  before do
    allow(Rails.logger).to receive(:warn) { |line| log_lines << line }
    promo = promotional
    fact = class_fact
    definition = definition_class do
      class_eval(&fact)
      promotional promo
    end
    stub_const("DefinedRenderSample", definition)
    register_and_seal_notification_types(
      build_notification_type_declaration(
        key: "defined.render", message: "DefinedRenderSample", label: "Class canceled", **declaration_overrides
      )
    )
  end

  describe "transactional footer (E-01)" do
    it "is outside the card with the preferences link in both parts" do
      expect(payload.html_body).to include(MessagingComplianceRenderHelper::FOOTER_SENTENCE,
                                           %(href="#{footer_origin}"), "Manage email preferences")
      expect(payload.html_body).not_to include(postal_address)
      expect(payload.text_body).to include("Class canceled emails are turned on",
                                           "Manage email preferences: #{footer_origin}")
    end

    context "without a preferences_path" do
      let(:preferences_path) { nil }

      it "links to the composed url" do
        expect(payload.html_body).to include(%(href="#{origin}"))
        expect(payload.text_body).to include("Manage email preferences: #{origin}")
      end
    end
  end

  describe "fallback email (E-02)" do
    before do
      allow(CommandTower::Messaging::Definitions::DocumentBuilder).to receive(:email).and_wrap_original do |orig, **kw|
        raise "composer bug" if kw[:profile].nil?

        orig.call(**kw)
      end
    end

    it "carries the same footer" do
      expect(payload.html_body).to include("Manage email preferences", %(href="#{footer_origin}"))
      expect(payload.text_body).to include("Manage email preferences: #{footer_origin}")
    end
  end

  describe "promotional footer (E-03)" do
    let(:promotional) { true }

    it "adds the postal address and the unsubscribe copy" do
      expect(payload.html_body).to include("class canceled are turned on", "Unsubscribe or manage email preferences",
                                           postal_address)
      expect(payload.text_body).to include("Unsubscribe or manage email preferences: #{footer_origin}", postal_address)
    end
  end

  describe "mandatory footer (E-06)" do
    let(:declaration_overrides) { { mandatory: true, user_configurable: false } }

    it "uses the account copy and no headers" do
      expect(payload.html_body).to include("sends this email about your account.", "Manage email preferences")
      expect(payload.text_body).to include("sends this email about your account.")
      expect(payload.headers).to eq({})
    end
  end

  describe "one-click headers (E-04, E-05)" do
    it "issues a verifiable token for the recipient and type" do
      expect(payload.headers["List-Unsubscribe-Post"]).to eq("List-Unsubscribe=One-Click")
      expect(header_url).to start_with("#{api_base_url}/messaging/unsubscribe?token=")
      expect(CommandTower::Services::Messaging::Unsubscribe::VerifyToken.call(token: header_token).data)
        .to include(user_id: 4242, notification_type_key: "defined.render")
    end

    it "keeps the token out of the body" do
      expect(payload.html_body).not_to include(header_token)
      expect(payload.text_body).not_to include(header_token)
    end

    context "without api_base_url" do
      let(:api_base_url) { nil }

      around do |example|
        previous = ENV.delete("COMMAND_TOWER_API_BASE_URL")
        example.run
      ensure
        ENV["COMMAND_TOWER_API_BASE_URL"] = previous if previous
      end

      it "omits the headers and keeps the footer identical" do
        expect(payload.headers).to eq({})
        expect(payload.html_body).to include("Manage email preferences")
      end
    end

    context "when the type is not user configurable" do
      let(:declaration_overrides) { { user_configurable: false } }

      it "omits the headers" do
        expect(payload.headers).to eq({})
      end
    end

    context "when the type does not allow email" do
      let(:declaration_overrides) do
        { allowed_channels: %w[sms], default_channels: %w[sms],
          default_preference_state: { "channels" => { "sms" => true }, "inbox" => true } }
      end

      it "is ineligible" do
        expect(CommandTower::Messaging::Rendering::UnsubscribeHeaders.eligible?(
                 CommandTower::Messaging::NotificationTypes.lookup("defined.render")
               )).to be(false)
      end
    end
  end

  describe "boot warning without api_base_url" do
    let(:api_base_url) { nil }

    around do |example|
      previous = ENV.delete("COMMAND_TOWER_API_BASE_URL")
      example.run
    ensure
      ENV["COMMAND_TOWER_API_BASE_URL"] = previous if previous
    end

    before do
      log_lines.clear
      CommandTower::Messaging::NotificationTypes::MessageDefinitionChecks.validate!(
        CommandTower::Messaging::NotificationTypes.enumerate
      )
    end

    it "logs one boot warning with type keys only" do
      expect(log_lines.grep(/unsubscribe headers omitted/).size).to eq(1)
      expect(log_lines.join).to include("types: defined.render")
    end
  end

  describe "undefined types" do
    let(:communication) do
      build(:messaging_communication, notification_type_key: "defined.render", title: "Generic title",
                                      body: "Generic body", user_id: 4242)
    end

    it "keeps the generic ERB with no footer and no headers" do
      expect(payload.html_body).not_to include("Manage email preferences")
      expect(payload.text_body).not_to include("Manage email preferences")
      expect(payload.headers).to eq({})
    end
  end

  describe "generic ERB last resort (E-11)" do
    before { allow(CommandTower::UI::Email::Renderer).to receive(:call).and_raise(StandardError, "renderer down") }

    it "has no footer and no headers" do
      expect(payload.html_body).not_to include("Manage email preferences")
      expect(payload.headers).to eq({})
    end
  end
end
