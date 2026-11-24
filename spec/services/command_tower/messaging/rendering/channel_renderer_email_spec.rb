# frozen_string_literal: true

# ChannelRenderer email for MessageDefinition-backed types: composer, the CT fallback document,
# the generic ERB last resort, and the text part with link targets.
RSpec.describe CommandTower::Messaging::Rendering::ChannelRenderer,
               :aggregate_failures, :defined_render, :messaging_notification_types do
  let(:metadata) do
    {
      "headline" => "Check in is open", "class_name" => "Arms & Abs", "door_code" => secret_code,
      "deep_link_path" => "/schedule"
    }
  end
  let(:communication) do
    build(
      :messaging_communication,
      id: 77, notification_type_key: "defined.render", title: "Generic title", body: "Generic body",
      metadata:, metadata_version: 1, render_zone: "America/Los_Angeles",
      slots: { "headline" => "Check in is open", "subject" => "Your class is open" }
    )
  end
  let(:payload) { render_channel("email", "recipient@example.com") }

  before do
    allow(Rails.logger).to receive(:warn) { |line| log_lines << line }
  end

  describe "composer" do
    context "with the basic layout" do
      before { register_definition(definition_class(&class_fact)) }

      it "uses the stored subject slot and the composed document" do
        expect(payload.subject).to eq("Your class is open")
        expect(payload.html_body).to include("<!DOCTYPE html>", "Check in is open", "Arms &amp; Abs")
        expect(payload.html_body).to include("href=\"#{origin}/schedule\"")
        expect(log_lines).to be_empty
      end

      it "writes label: https://... for the button in the text part" do
        expect(payload.text_body).to include("Check in is open", "Class: Arms & Abs")
        expect(payload.text_body).to match(%r{^Open in .+: #{Regexp.escape(origin)}/schedule$})
      end

      it "falls back to the title when no subject slot is stored" do
        communication.slots = { "headline" => "Check in is open" }

        expect(payload.subject).to eq("Generic title")
      end
    end

    context "with a link span" do
      before do
        fact = class_fact
        register_definition(
          definition_class do
            class_eval(&fact)
            define_method(:email) do |builder, **|
              builder.card(surface: :raised) do |c|
                c.text("See ", builder.link("the schedule", action: builder.navigate(path: "/schedule")))
                c.facts
              end
            end
          end
        )
      end

      it "appends the link target line" do
        expect(payload.text_body).to include("See the schedule\nthe schedule: #{origin}/schedule")
      end
    end
  end

  describe "G2 button rule" do
    before { register_definition(definition_class(&class_fact)) }

    context "without a deep link" do
      let(:metadata) { { "headline" => "Check in is open", "class_name" => "Arms" } }

      it "renders no button" do
        expect(payload.html_body).not_to include("<a ")
        expect(payload.text_body).not_to include("https://")
      end
    end

    context "with a cta_label" do
      let(:metadata) do
        { "headline" => "Check in is open", "class_name" => "Arms", "deep_link_path" => "/schedule",
          "cta_label" => "See it" }
      end

      it "uses the label" do
        expect(payload.text_body).to include("See it: #{origin}/schedule")
      end
    end
  end

  describe "fallback document" do
    context "when the composer raises" do
      before do
        fact = class_fact
        register_definition(
          definition_class do
            class_eval(&fact)
            define_method(:email) { |_builder, **| raise "composer bug" }
          end
        )
      end

      it "renders headline, derived fact text and the CTA, logging ids only" do
        expect(payload.html_body).to include("Check in is open", "Arms &amp; Abs")
        expect(payload.text_body).to include("Class: Arms & Abs", "#{origin}/schedule")
        expect(payload.subject).to eq("Your class is open")
        expect(log_lines.join).to include("email_document_fallback communication_id=77", "error_class=RuntimeError")
        expect(log_lines.join).not_to include("composer bug", "Arms")
      end
    end

    context "when a code node is in the document" do
      before { register_definition(definition_class(&class_and_code_fact)) }

      it "forces the fallback and never carries the code value" do
        expect(payload.html_body).to include("Check in is open", "Arms &amp; Abs")
        expect(payload.html_body).not_to include(secret_code)
        expect(payload.text_body).not_to include(secret_code)
        expect(log_lines.join).to include("email_document_fallback", "error_class=CommandTower::UI::InvalidDocumentError")
        expect(log_lines.join).not_to include(secret_code)
      end
    end

    context "when the definition has no fact block" do
      before { register_definition(definition_class) }

      it "falls back to the communication body" do
        expect(payload.text_body).to include("Check in is open", "Generic body", "#{origin}/schedule")
        expect(log_lines.join).to include("email_document_fallback")
      end
    end
  end

  describe "generic ERB last resort (E-11)" do
    before do
      register_definition(definition_class(&class_fact))
      allow(CommandTower::UI::Email::Renderer).to receive(:call).and_raise(StandardError, "renderer down")
    end

    it "renders today's generic ERB with the stored subject and no footer" do
      expect(payload.subject).to eq("Your class is open")
      expect(payload.html_body).to include("Generic body")
      expect(payload.text_body).to include("Generic body")
      expect(log_lines.join).to include("email_erb_fallback")
    end

    context "when the ERB also fails" do
      before do
        allow(CommandTower::Messaging::Rendering::TemplateResolver).to receive(:render).and_raise(StandardError)
      end

      it "raises render_failed" do
        expect { payload }.to raise_error(CommandTower::Messaging::Rendering::RenderError) { |e|
          expect(e.code).to eq("render_failed")
        }
      end
    end
  end
end
