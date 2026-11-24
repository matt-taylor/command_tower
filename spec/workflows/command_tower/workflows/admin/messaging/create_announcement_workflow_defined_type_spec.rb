# frozen_string_literal: true

# D26: the admin announcement endpoint for undefined types (unchanged), for AnnouncementDefinition
# types (title/body mapped into metadata) and for other defined types (422).
RSpec.describe CommandTower::Workflows::Admin::Messaging::CreateAnnouncementWorkflow, :messaging_accept do
  let(:type_key) { "promotional_announcement" }
  let(:message) { nil }
  let(:metadata) { nil }
  let(:title) { "You're invited" }
  let(:body) { "Book **here**" }

  include AnnouncementWorkflowHelpers

  before do
    stub_const("StubAnnouncementSubclass", Class.new(CommandTower::Messaging::AnnouncementDefinition))
    register_and_seal_notification_types(
      build_notification_type_declaration(
        key: type_key, allowed_channels: %w[email], default_channels: %w[email], message:,
        default_preference_state: { "channels" => { "email" => true }, "inbox" => true }
      )
    )
    allow(CommandTower.config.messaging).to receive_messages(
      platform_enabled_channels: -> { %w[email] },
      resolve_announcement_audience: ->(selection) { Array(selection.with_indifferent_access[:ids]).map(&:to_i) }
    )
  end

  context "with an undefined type (regression)" do
    let(:metadata) { { "deep_link_path" => "/classes" } }

    it "produces the given title and body unchanged", :aggregate_failures do
      expect(result).to be_success
      expect(communications.pluck(:title).uniq).to eq([title])
      expect(communications.pluck(:body).uniq).to eq([body])
    end

    it "keeps the given metadata and stores no slots", :aggregate_failures do
      result
      expect(communications.map(&:metadata).uniq).to eq([{ "deep_link_path" => "/classes" }])
      expect(communications.map(&:slots)).to all(be_blank)
    end
  end

  context "with an AnnouncementDefinition type" do
    let(:message) { "CommandTower::Messaging::AnnouncementDefinition" }
    let(:metadata) { { "deep_link_path" => "/classes" } }

    it "maps title and body into metadata", :aggregate_failures do
      expect(result).to be_success
      expect(communications.count).to eq(2)
      expect(communications.first.metadata).to include(
        "title" => title, "body_markdown" => body, "deep_link_path" => "/classes"
      )
    end

    it "stores the derived title, slots and version", :aggregate_failures do
      result
      expect(communications.first.title).to eq(title)
      expect(communications.first.slots).to include("headline" => title, "subject" => title)
      expect(communications.first.metadata_version).to eq(1)
    end

    context "when the title is longer than 200 characters" do
      let(:title) { "t" * 201 }

      it "fails with 422 and names the attribute", :aggregate_failures do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unprocessable_entity)
        expect(result.errors.first.details.to_s).to include("title")
        expect(communications).to be_empty
      end
    end
  end

  context "with a subclass of AnnouncementDefinition" do
    let(:message) { "StubAnnouncementSubclass" }

    it "is accepted as an announcement type" do
      expect(result).to be_success
    end
  end

  context "with any other defined type" do
    let(:type_key) { "class_canceled" }
    let(:message) { "ClassCanceled" }

    it "fails with 422 announcement_type_not_supported and produces nothing", :aggregate_failures do
      expect(result).to be_failure
      expect(result.http_status).to eq(:unprocessable_entity)
      expect(result.errors.first.code).to eq("announcement_type_not_supported")
      expect(communications).to be_empty
    end
  end
end
