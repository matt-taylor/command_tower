# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Rendering::TemplateResolver, :messaging_rich_messaging_proof do
  describe ".render_type_template" do
    context "when a type template exists for the basename and format" do
      subject(:result) do
        described_class.render_type_template(
          basename: "email", format: :html, notification_type_key: "rich_messaging_proof",
          locals: { h: ->(text) { text }, title: "Type Override" },
        )
      end

      it "returns the rendered template body" do
        expect(result).to include("PROOF OVERRIDE: Type Override")
      end
    end

    context "when no type template exists for the basename" do
      subject(:result) do
        described_class.render_type_template(
          basename: "inbox_document", format: :json, notification_type_key: "rich_messaging_unregistered", locals: {},
        )
      end

      it "returns nil instead of raising" do
        expect(result).to be_nil
      end
    end

    context "when the notification_type_key fails the sanitized-key pattern" do
      subject(:result) do
        described_class.render_type_template(
          basename: "inbox_document", format: :json, notification_type_key: "example.type", locals: {},
        )
      end

      it "returns nil without attempting a lookup" do
        expect(result).to be_nil
      end
    end

    context "when the type template raises mid-render" do
      subject(:result_call) do
        described_class.render_type_template(
          basename: "email", format: :html, notification_type_key: "rich_messaging_malformed", locals: {},
        )
      end

      it "propagates the original error class" do
        expect { result_call }.to raise_error(NameError, /boom from fixture/)
      end
    end
  end
end
