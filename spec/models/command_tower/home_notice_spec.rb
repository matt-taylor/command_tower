# frozen_string_literal: true

RSpec.describe CommandTower::HomeNotice do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  let(:build_notice) do
    lambda do |**attrs|
      described_class.new({ user:, kind: "campaign", key: "welcome", campaign_key: "welcome" }.merge(attrs))
    end
  end

  let(:normalized_period_key) do
    ->(value) { build_notice.call(period_key: value).tap(&:valid?).period_key }
  end

  describe "defaults and public id" do
    subject(:notice) { build_notice.call.tap(&:save!) }

    it "assigns a 32 character public id" do
      expect(notice.public_id).to match(/\A[A-Za-z0-9]{32}\z/)
    end

    it "defaults period_key to an empty string" do
      expect(notice.period_key).to eq("")
    end

    it "defaults impression_count to zero" do
      expect(notice.reload.impression_count).to eq(0)
    end
  end

  describe "validations" do
    subject(:notice) { build_notice.call(kind: nil, key: nil) }

    before { notice.valid? }

    it "requires kind" do
      expect(notice.errors[:kind]).to be_present
    end

    it "requires key" do
      expect(notice.errors[:key]).to be_present
    end
  end

  describe "campaign uniqueness" do
    before { build_notice.call.save! }

    context "with a second row and an empty period_key for the same user and campaign" do
      subject(:duplicate) { build_notice.call }

      before { duplicate.valid? }

      it "rejects it" do
        expect(duplicate.errors[:period_key]).to be_present
      end
    end

    it "enforces uniqueness in the database too" do
      expect { build_notice.call(public_id: "other-public-id").save!(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows a different period_key" do
      expect(build_notice.call(period_key: "2026-12")).to be_valid
    end

    it "allows the same campaign for another user" do
      expect(build_notice.call(user: other_user)).to be_valid
    end
  end

  describe "deliveries" do
    before { build_notice.call(kind: "delivery", campaign_key: nil, identity: "a").save! }

    it "allows many rows with a NULL campaign_key and distinct identities" do
      expect { build_notice.call(kind: "delivery", campaign_key: nil, identity: "b").save! }.not_to raise_error
    end

    context "with a duplicate identity for the same user" do
      subject(:duplicate) { build_notice.call(kind: "delivery", campaign_key: nil, identity: "a") }

      before { duplicate.valid? }

      it "rejects it" do
        expect(duplicate.errors[:identity]).to be_present
      end
    end
  end

  describe "period_key normalization" do
    let(:long) { "x" * 300 }

    it "stores the value as a string" do
      expect(normalized_period_key.call(202_612)).to eq("202612")
    end

    it "truncates an over-long value to the column limit" do
      expect(normalized_period_key.call(long).length).to eq(191)
    end

    it "is deterministic for the same input" do
      expect(normalized_period_key.call(long.dup)).to eq(normalized_period_key.call(long))
    end

    it "gives different results for inputs that differ only after the truncation point" do
      expect(normalized_period_key.call("#{long}y")).not_to eq(normalized_period_key.call(long))
    end
  end
end
