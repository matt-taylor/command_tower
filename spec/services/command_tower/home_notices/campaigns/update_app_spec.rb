# frozen_string_literal: true

RSpec.describe CommandTower::HomeNotices::Campaigns::UpdateApp do
  subject(:notice) { described_class.new }

  let(:user) { create(:user) }
  let(:projection) do
    { platform: "ios", currentVersion: "1.0.0", recommendedVersion: "1.2.0", updateAvailable: true,
      recovery: "app_store", updateUrl: "https://apps.example.com/app" }
  end
  let(:request_context) do
    CommandTower::HomeNotices::Context.new(
      now: Time.utc(2026, 1, 1), time_zone: "UTC", app_version: "1.0.0", platform: "ios", ui_catalog: 2,
      client_compatibility: projection, impersonating: false
    )
  end
  let(:document_text) do
    result = CommandTower::Services::HomeNotices::Compose.call(
      notice_class: described_class, user:, request_context:, record: nil
    )
    result.data[:document].as_json.to_json
  end

  after { CommandTower::HomeNotices::Catalog.reset! }

  it "is a dismissible platform campaign with the reserved key", :aggregate_failures do
    expect(described_class.key).to eq("ct.update_app")
    expect(described_class).to be_dismissible
    expect(CommandTower::HomeNotices::Catalog.validate!(described_class, builtin: true)).to eq(described_class)
  end

  it "is rejected by the catalog validator for host notices" do
    expect(CommandTower::HomeNotices::Catalog::Validator.errors_for(described_class).join).to include("reserved")
  end

  describe "#show?" do
    it "shows when an update is available" do
      expect(notice.show?(user:, context: request_context, notice: nil)).to be(true)
    end

    context "when no update is available" do
      let(:projection) { super().merge(updateAvailable: false) }

      it "does not show" do
        expect(notice.show?(user:, context: request_context, notice: nil)).to be(false)
      end
    end

    it "does not show without a recommendation" do
      expect(notice.show?(user:, context: request_context.with(client_compatibility: nil), notice: nil)).to be(false)
    end
  end

  describe "period_key" do
    it "changes with the recommended version" do
      expect(
        [request_context, request_context.with(client_compatibility: projection.merge(recommendedVersion: "1.3.0"))]
          .map { |context| described_class.period_key.call(user:, context:) }
      ).to eq(%w[1.2.0 1.3.0])
    end
  end

  describe "document" do
    it "carries the copy, both versions and an Update now button for an https URL", :aggregate_failures do
      expect(document_text).to include("A new version is ready", "Update to get the latest fixes and improvements.")
      expect(document_text).to include("Your version", "1.0.0", "Latest", "1.2.0", "Update now",
                                       "https://apps.example.com/app")
    end

    context "without an https update URL" do
      let(:projection) { super().merge(updateUrl: nil, recommendedVersion: "1.2.0") }

      it "has no button and uses the app store copy", :aggregate_failures do
        expect(document_text).to include("Update from your device's app store to get the latest fixes")
        expect(document_text).not_to include("Update now")
      end
    end

    context "with a non-https update URL" do
      let(:projection) { super().merge(updateUrl: "http://apps.example.com/app") }

      it "has no button" do
        expect(document_text).not_to include("Update now")
      end
    end
  end

  describe "selection" do
    before do
      allow(CommandTower.config.home_notices).to receive(:update_app_campaign).and_return(true)
      CommandTower::HomeNotices::Catalog.load!([])
    end

    it "picks it when an update is available" do
      expect(CommandTower::Services::HomeNotices::Select.call(user:, request_context:).data[:dismissible].notice_class)
        .to eq(described_class)
    end

    context "when no update is available" do
      let(:projection) { super().merge(updateAvailable: false) }

      it "picks nothing" do
        expect(CommandTower::Services::HomeNotices::Select.call(user:, request_context:).data[:dismissible]).to be_nil
      end
    end

    context "with a newer recommended version than a spent row" do
      let(:projection) { super().merge(recommendedVersion: "1.3.0") }

      before do
        CommandTower::HomeNotice.create!(
          user:, kind: "campaign", key: "ct.update_app", campaign_key: "ct.update_app", period_key: "1.2.0",
          impression_count: 3, last_shown_at: request_context.now - 2.days
        )
      end

      it "is a fresh candidate again" do
        expect(CommandTower::Services::HomeNotices::Select.call(user:, request_context:).data[:dismissible])
          .to have_attributes(notice_class: described_class, record: nil)
      end
    end
  end

  describe "catalog inclusion" do
    before do
      allow(CommandTower.config.home_notices).to receive(:update_app_campaign).and_return(campaign_enabled)
      CommandTower::HomeNotices::Catalog.load!([])
    end

    context "when update_app_campaign is true" do
      let(:campaign_enabled) { true }

      it "is registered" do
        expect(CommandTower::HomeNotices::Catalog.campaign("ct.update_app")).to eq(described_class)
      end
    end

    context "when update_app_campaign is false" do
      let(:campaign_enabled) { false }

      it "is left out" do
        expect(CommandTower::HomeNotices::Catalog.campaign("ct.update_app")).to be_nil
      end
    end
  end
end
