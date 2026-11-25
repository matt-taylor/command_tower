# frozen_string_literal: true

RSpec.describe CommandTower::HomeNotices::Catalog do
  # A valid dismissible campaign; `extra` is class-evaluated on top to break one rule at a time.
  let(:build_campaign) do
    base = CommandTower::HomeNotices::Campaign
    lambda do |key: "pickem.make_your_picks", &extra|
      Class.new(base) do
        self.key(key) if key
        severity :dismissible
        priority 50
        impressions max: 4, cooldown: 12.hours
        define_method(:show?) { |**| true }
        define_method(:compose) { |*, **| nil }
        class_eval(&extra) if extra
      end
    end
  end

  let(:build_delivery) do
    base = CommandTower::HomeNotices::Delivery
    lambda do |linked: false, &extra|
      Class.new(base) do
        key "dfm.class_canceled"
        severity :dismissible
        priority 10
        composer :message if linked
        class_eval(&extra) if extra
      end
    end
  end

  let(:valid_delivery) do
    build_delivery.call do
      define_method(:show?) { |**| true }
      define_method(:compose) { |*, **| nil }
    end
  end

  let(:load_error) do
    catalog = described_class
    lambda do |*classes|
      catalog.load!(classes)
      nil
    rescue catalog::InvalidNoticeError => e
      e.message
    end
  end

  after { described_class.reset! }

  describe ".load!" do
    context "with a campaign and a delivery" do
      let(:campaign) { build_campaign.call }

      before { described_class.load!([campaign, valid_delivery]) }

      it "lists both notices" do
        expect(described_class.notices).to eq([campaign, valid_delivery])
      end

      it "indexes the campaign by key" do
        expect(described_class.campaign(campaign.key)).to eq(campaign)
      end

      it "does not index the delivery" do
        expect(described_class.campaign(valid_delivery.key)).to be_nil
      end
    end

    context "with a class name" do
      before { stub_const("SampleCatalogNotice", build_campaign.call) }

      it "constantizes class names" do
        expect(described_class.load!(["SampleCatalogNotice"])).to eq([SampleCatalogNotice])
      end
    end

    it "rejects an unknown class name" do
      expect(load_error.call("Nope::Missing")).to include("unknown class")
    end

    it "rejects a class that is not a Campaign or Delivery" do
      expect(load_error.call(Class.new(CommandTower::HomeNotices::Notice))).to include("must subclass")
    end

    it "rejects a missing key" do
      expect(load_error.call(build_campaign.call(key: nil))).to include("key is required")
    end

    it "rejects an invalid key" do
      expect(load_error.call(build_campaign.call(key: "NoDots"))).to include("must match")
    end

    it "rejects the reserved ct. prefix" do
      expect(load_error.call(build_campaign.call(key: "ct.thing"))).to include("reserved")
    end

    it "rejects duplicate keys" do
      expect(load_error.call(build_campaign.call, build_campaign.call)).to include("duplicate notice key")
    end

    it "rejects a missing severity" do
      expect(load_error.call(build_campaign.call { @severity = nil })).to include("severity is required")
    end

    it "rejects a missing priority" do
      expect(load_error.call(build_campaign.call { @priority = nil })).to include("priority is required")
    end

    it "rejects a show? that is not overridden" do
      expect(load_error.call(build_campaign.call { remove_method(:show?) })).to include("show? must be overridden")
    end

    it "rejects a compose that is not overridden" do
      expect(load_error.call(build_campaign.call { remove_method(:compose) })).to include("compose must be overridden")
    end

    context "with a linked delivery" do
      let(:klass) { build_delivery.call(linked: true) { define_method(:show?) { |**| true } } }

      it "does not require compose" do
        expect(load_error.call(klass)).to be_nil
      end
    end

    context "with a blocking campaign and a short blocking_reason" do
      let(:klass) do
        build_campaign.call do
          severity :blocking
          blocking_reason "too short"
        end
      end

      it "rejects it" do
        expect(load_error.call(klass)).to include("blocking_reason")
      end
    end

    context "with a blocking campaign and a long blocking_reason" do
      let(:klass) do
        build_campaign.call do
          severity :blocking
          blocking_reason "Terms of service changed today"
        end
      end

      it "accepts it" do
        expect(load_error.call(klass)).to be_nil
      end
    end

    it "rejects a Delivery macro on a campaign" do
      expect(load_error.call(build_campaign.call { define_singleton_method(:composer) { :message } }))
        .to include("composer is a Delivery macro")
    end

    it "rejects a Campaign macro on a delivery" do
      expect(load_error.call(build_delivery.call { define_singleton_method(:impressions) { nil } }))
        .to include("Campaign macros")
    end

    it "rejects a dismissible campaign without impressions" do
      expect(load_error.call(build_campaign.call { @impressions = nil })).to include("must declare impressions")
    end

    context "with an unordered window" do
      let(:klass) { build_campaign.call { window starts_at: Time.utc(2026, 2, 1), ends_at: Time.utc(2026, 1, 1) } }

      it "rejects it" do
        expect(load_error.call(klass)).to include("starts_at must be before")
      end
    end

    context "when Delivery#show? is defined on the base" do
      before { CommandTower::HomeNotices::Delivery.define_method(:show?) { |**| true } }

      after { CommandTower::HomeNotices::Delivery.send(:remove_method, :show?) }

      it "rejects an unlinked delivery that only inherits it" do
        expect(load_error.call(build_delivery.call { define_method(:compose) { |*, **| nil } }))
          .to include("show? must be")
      end

      it "accepts a linked delivery" do
        expect(load_error.call(build_delivery.call(linked: true))).to be_nil
      end
    end
  end
end
