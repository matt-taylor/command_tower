# frozen_string_literal: true

require Rails.root.join("test/mailers/previews/message_definition_preview").to_s

RSpec.describe MessageDefinitionPreview, :aggregate_failures do
  it "lists the three previews" do
    expect(described_class.emails).to match_array(%w[sample_email sample_email_fallback sample_email_user_zone])
  end

  described_class.emails.each do |preview|
    describe preview do
      let(:mail) { described_class.new.public_send(preview) }

      it "renders html and text parts with the stored subject" do
        expect(mail.subject).to include("Arms & Abs is canceled")
        expect(mail.html_part.body.decoded).to include("<!DOCTYPE html>", "Arms &amp; Abs")
        expect(mail.text_part.body.decoded).to include("Arms & Abs")
      end
    end
  end

  describe "sample_email_fallback" do
    before do
      allow(Rails.logger).to receive(:warn)
      described_class.new.sample_email_fallback
    end

    it "renders the fallback document when the composer fails" do
      expect(Rails.logger).to have_received(:warn).with(/email_document_fallback .*error_class=RuntimeError/)
    end
  end

  describe "sample_email" do
    before do
      allow(Rails.logger).to receive(:warn)
      described_class.new.sample_email
    end

    it "does not log a fallback for the composer previews" do
      expect(Rails.logger).not_to have_received(:warn).with(/email_document_fallback/)
    end
  end
end
