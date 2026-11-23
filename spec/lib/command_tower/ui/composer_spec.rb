# frozen_string_literal: true

RSpec.describe CommandTower::UI::Composer, :aggregate_failures do
  let(:starts_at) { Time.utc(2025, 12, 4, 14) }

  describe ".call" do
    let(:document) { SampleHostUI::ClassCanceled.call(starts_at:, room: "Studio B") }

    it "returns a validated Document" do
      expect(document).to be_a(CommandTower::UI::Document)
      expect(document.validation_errors).to be_empty
    end

    it "derives the text fallback from the tree" do
      expect(document.text_fallback).to eq(
        "Class canceled\nWhere: Studio B\nWhen: Thu, Dec 4, 6:00 AM PT\nView classes"
      )
    end

    it "expands fragments into primitives" do
      expect(document.as_json["root"]["children"].pluck("type")).to eq(%w[text key_value key_value code button])
    end

    it "keeps the code value out of the fallback" do
      expect(document.text_fallback).not_to include("424242")
    end

    it "honours a text_fallback override" do
      expect(SampleHostUI::CustomFallback.call.text_fallback).to eq("Custom")
    end
  end

  describe "invalid results" do
    it "raises InvalidDocumentError when no root is composed" do
      expect { SampleHostUI::Empty.call }.to raise_error(CommandTower::UI::InvalidDocumentError, /root_required/)
    end

    it "raises when the composed document fails validation" do
      expect { SampleHostUI::ClassCanceled.call(starts_at: "nope", room: "B") }
        .to raise_error(CommandTower::UI::InvalidDocumentError) { |error|
          expect(error.details).to include({ path: "root.children[2].items[0].value.at", code: "invalid" })
        }
    end

    it "requires subclasses to implement compose" do
      expect { described_class.call }.to raise_error(NotImplementedError)
    end
  end
end
