# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Rendering::ChannelRenderer, :defined_render, :messaging_accept do
  let(:user) { create(:user, email: "recipient@example.com") }
  let(:slots) do
    {
      "headline" => "Spin class canceled",
      "push_body" => "Tonight's 6:00 PM class is canceled.",
      "sms_body" => "Studio: class canceled at 6:00 PM.",
      "pushover_title" => "Class canceled",
      "pushover_message" => "Tonight's 6:00 PM class is canceled."
    }
  end
  let(:metadata) { { "deep_link" => "https://example.com/classes/1" } }
  let(:communication) do
    create(
      :messaging_communication,
      user:, title: "Generic title", body: "Generic body", metadata:,
      metadata_version: 1, slots:, render_zone: "America/New_York"
    )
  end

  describe "defined types (stored slots)" do
    context "with push" do
      let(:payload) { render_channel("push", "99") }

      it "renders the headline as the title", :aggregate_failures do
        expect(payload.title).to eq("Spin class canceled")
        expect(payload.body).to eq("Tonight's 6:00 PM class is canceled.")
      end

      it "keeps the metadata deep link" do
        expect(payload.deep_link).to eq("https://example.com/classes/1")
      end
    end

    it "uses the headline as the push body when push_body is absent" do
      slots.delete("push_body")

      expect(render_channel("push", "99").body).to eq("Spin class canceled")
    end

    it "renders SMS from sms_body with the deep link appended" do
      expect(render_channel("sms", "+14155552671").body)
        .to eq("Studio: class canceled at 6:00 PM. https://example.com/classes/1")
    end

    context "with Pushover" do
      let(:payload) { render_channel("pushover", "42") }

      it "renders its slots with the deep link appended", :aggregate_failures do
        expect(payload.title).to eq("Class canceled")
        expect(payload.message).to eq("Tonight's 6:00 PM class is canceled. https://example.com/classes/1")
      end
    end

    context "without a deep link" do
      let(:metadata) { nil }

      it "appends nothing to SMS" do
        expect(render_channel("sms", "+14155552671").body).to eq("Studio: class canceled at 6:00 PM.")
      end
    end

    context "when a slot is missing" do
      before { slots.delete("sms_body") }

      it "falls back to the generic template for that channel" do
        expect(render_channel("sms", "+14155552671").body).to include("Generic title: Generic body")
      end
    end
  end

  describe "undefined types" do
    let(:communication) do
      create(:messaging_communication, user:, title: "Generic title", body: "Generic body", metadata:)
    end

    it "ignores slots and keeps the generic templates", :aggregate_failures do
      expect(render_channel("push", "99").body).to eq("Generic body")
      expect(render_channel("sms", "+14155552671").body)
        .to eq("Generic title: Generic body https://example.com/classes/1")
      expect(render_channel("pushover", "42").message).to eq("Generic body https://example.com/classes/1")
    end
  end
end
