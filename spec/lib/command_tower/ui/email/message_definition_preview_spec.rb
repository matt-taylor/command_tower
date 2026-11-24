# frozen_string_literal: true

require Rails.root.join("test/mailers/previews/message_definition_preview").to_s

RSpec.describe MessageDefinitionPreview, :aggregate_failures, :messaging_notification_types do
  # Other messaging specs reset the registry the host initializer fills at boot, so register the
  # two types the previews render (the compliance footer looks the declaration up by key).
  before do
    email_only = {
      allowed_channels: %w[email], default_channels: %w[email],
      default_preference_state: { "channels" => { "email" => true }, "inbox" => true }
    }
    register_and_seal_notification_types(
      build_notification_type_declaration(
        key: "class_canceled", label: "Class canceled", message: "ClassCanceled", **email_only
      ),
      build_notification_type_declaration(
        key: "membership_renewal", label: "Membership renewal", message: "MembershipRenewal", **email_only
      ),
      build_notification_type_declaration(
        key: "promotional_announcement", label: "Promotional announcement",
        message: "CommandTower::Messaging::AnnouncementDefinition", **email_only
      )
    )
  end

  it "lists the previews" do
    expect(described_class.emails).to match_array(
      %w[sample_email sample_email_fallback sample_email_user_zone sample_email_promotional
         sample_email_without_api_base_url announcement_email announcement_email_without_api_base_url]
    )
  end

  %w[announcement_email announcement_email_without_api_base_url].each do |preview|
    describe preview do
      let(:mail) { described_class.new.public_send(preview) }
      let(:address) { CommandTower.config.messaging.compliance.postal_address }

      it "renders the announcement with the promotional footer", :aggregate_failures do
        expect(mail.subject).to eq("New classes this week")
        expect(mail.html_part.body.decoded).to include("<!DOCTYPE html>", "New classes this week", "schedule")
        expect(mail.text_part.body.decoded).to include("Unsubscribe or manage email preferences", address)
      end
    end
  end

  describe "announcement one-click headers panel" do
    context "with announcement_email" do
      let(:mail) { described_class.new.announcement_email }

      it "shows List-Unsubscribe and List-Unsubscribe-Post" do
        expect(mail["List-Unsubscribe"].value).to match(%r{\A<https?://.+/messaging/unsubscribe\?token=.+>\z})
        expect(mail["List-Unsubscribe-Post"].value).to eq("List-Unsubscribe=One-Click")
      end
    end

    context "with announcement_email_without_api_base_url" do
      let(:mail) { described_class.new.announcement_email_without_api_base_url }

      it "shows neither header" do
        expect(mail["List-Unsubscribe"]).to be_nil
        expect(mail["List-Unsubscribe-Post"]).to be_nil
      end
    end
  end

  describe "compliance footer variants" do
    let(:address) { CommandTower.config.messaging.compliance.postal_address }

    context "with the promotional variant" do
      let(:text) { described_class.new.sample_email_promotional.text_part.body.decoded }

      it "shows the postal address and unsubscribe link" do
        expect(text).to include("Unsubscribe or manage email preferences", address)
      end
    end

    context "with the transactional variant" do
      let(:text) { described_class.new.sample_email_without_api_base_url.text_part.body.decoded }

      it "omits the postal address" do
        expect(text).to include("Manage email preferences")
        expect(text).not_to include(address)
      end
    end
  end

  %w[sample_email sample_email_fallback].each do |preview|
    describe preview do
      let(:mail) { described_class.new.public_send(preview) }

      it "renders html and text parts with the stored subject" do
        expect(mail.subject).to include("Arms & Abs is canceled")
        expect(mail.html_part.body.decoded).to include("<!DOCTYPE html>", "Arms &amp; Abs")
        expect(mail.text_part.body.decoded).to include("Arms & Abs")
      end
    end
  end

  describe "sample_email_user_zone" do
    let(:mail) { described_class.new.sample_email_user_zone }

    it "renders the membership renewal time in the recipient zone" do
      expect(mail.subject).to include("Unlimited Monthly membership renews")
      expect(mail.html_part.body.decoded).to include("<!DOCTYPE html>", "Unlimited Monthly", "ET")
      expect(mail.text_part.body.decoded).to include("Unlimited Monthly", "ET")
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
