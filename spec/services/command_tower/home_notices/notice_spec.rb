# frozen_string_literal: true

RSpec.describe CommandTower::HomeNotices::Notice do
  let(:campaign_class) do
    Class.new(CommandTower::HomeNotices::Campaign) do
      key "pickem.make_your_picks"
      severity :dismissible
      priority 50
      impressions max: 4, cooldown: 12.hours
      period_key { |user:, context:| [user, context] }
    end
  end

  let(:delivery_class) do
    Class.new(CommandTower::HomeNotices::Delivery) do
      key "dfm.class_canceled"
      severity :blocking
      blocking_reason "Terms changed"
      composer :message
      window starts_at: Time.utc(2026, 1, 1), ends_at: Time.utc(2026, 2, 1)
    end
  end

  describe "campaign macros" do
    it { expect(campaign_class.key).to eq("pickem.make_your_picks") }
    it { expect(campaign_class.severity).to eq(:dismissible) }
    it { expect(campaign_class).to be_dismissible }
    it { expect(campaign_class.priority).to eq(50) }
    it { expect(campaign_class.impressions.max).to eq(4) }
    it { expect(campaign_class.impressions.cooldown).to eq(12.hours) }
    it { expect(campaign_class.period_key.call(user: 1, context: 2)).to eq([1, 2]) }
  end

  describe "delivery macros" do
    it { expect(delivery_class).to be_blocking }
    it { expect(delivery_class.blocking_reason).to eq("Terms changed") }
    it { expect(delivery_class.composer).to eq(:message) }
    it { expect(delivery_class.window.starts_at).to eq(Time.utc(2026, 1, 1)) }
  end

  describe "inheritance" do
    let(:child) { Class.new(campaign_class) { priority 99 } }

    it { expect(child.key).to eq("pickem.make_your_picks") }
    it { expect(child.impressions.max).to eq(4) }
    it { expect(child.priority).to eq(99) }

    it "does not change the parent when a child overrides" do
      child
      expect(campaign_class.priority).to eq(50)
    end
  end

  describe "macros on the wrong kind" do
    let(:base_delivery) { Class.new(CommandTower::HomeNotices::Delivery) }
    let(:base_campaign) { Class.new(CommandTower::HomeNotices::Campaign) }

    it { expect { base_delivery.impressions(max: 1, cooldown: 1) }.to raise_error(NoMethodError) }
    it { expect { base_delivery.period_key { 1 } }.to raise_error(NoMethodError) }
    it { expect { base_campaign.composer(:message) }.to raise_error(NoMethodError) }
  end

  describe "invalid macro values" do
    let(:base_delivery) { Class.new(CommandTower::HomeNotices::Delivery) }
    let(:base_campaign) { Class.new(CommandTower::HomeNotices::Campaign) }

    it { expect { base_campaign.severity(:loud) }.to raise_error(ArgumentError) }
    it { expect { base_campaign.priority("high") }.to raise_error(ArgumentError) }
    it { expect { base_delivery.composer(:sms) }.to raise_error(ArgumentError) }
  end

  describe "instance defaults" do
    it { expect(campaign_class.new.show?(user: nil, context: nil, notice: nil)).to be(true) }
    it { expect(campaign_class.new.compose(nil, user: nil, context: nil, notice: nil)).to be_nil }
  end

  describe CommandTower::HomeNotices::Context do
    let(:context) do
      described_class.new(now: Time.utc(2026, 1, 1), time_zone: "UTC", app_version: "1.0", platform: "ios",
                          ui_catalog: 1, client_compatibility: nil, impersonating: false)
    end

    it { expect(context.platform).to eq("ios") }
    it { expect(context).to be_frozen }
  end

  describe CommandTower::HomeNotices::NoticeRecord do
    let(:row) do
      CommandTower::HomeNotice.create!(user: create(:user), kind: "delivery", key: "dfm.class_canceled",
                                       identity: "x/1", metadata: { "class_id" => 7 })
    end
    let(:record) { described_class.from(row) }

    it { expect(record.key).to eq("dfm.class_canceled") }
    it { expect(record.metadata["class_id"]).to eq(7) }
    it { expect(record).to be_frozen }
    it { expect(record.metadata).to be_frozen }
  end
end
