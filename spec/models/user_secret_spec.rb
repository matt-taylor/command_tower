# == Schema Information
#
# Table name: user_secrets
#
#  id            :bigint           not null, primary key
#  death_time    :datetime
#  extra         :string(255)
#  reason        :string(255)
#  secret        :string(255)
#  use_count     :integer          default(0)
#  use_count_max :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_user_secrets_on_secret   (secret) UNIQUE
#  index_user_secrets_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#

RSpec.describe UserSecret, type: :model do
  let!(:record) { described_class.create!(**params) }
  let(:params) do
    {
      user:,
      death_time:,
      extra:,
      reason:,
      secret:,
      use_count_max:,
    }.compact
  end

  let(:user) { create(:user) }
  let(:death_time) { 5.minutes.from_now }
  let(:extra) { "some random extra string" }
  let(:reason) { "login" }
  let(:secret) { "aSuperSecretValu3" }
  let(:use_count_max) { 10 }

  describe ".find_record" do
    subject(:find_record) { described_class.find_record(secret: input_secret, reason:, access_count:) }

    let(:access_count) { true }
    let(:input_secret) { secret }
    it do
      expect(find_record).to include(
        found: true,
        valid: true,
        record:,
        user:,
      )
    end

    it "changes access count" do
      expect { find_record }.to change { record.reload.use_count }.by(1)
    end

    context "when invalid record" do
      let(:use_count_max) { -1 }

      it do
        expect(find_record).to eq(
          found: true,
          valid: false,
          record:,
          user:,
        )
      end

      it "changes access count" do
        expect { find_record }.to change { record.reload.use_count }.by(1)
      end
    end

    context "with no reason" do
      it do
        expect(find_record).to eq(
          found: true,
          valid: true,
          record:,
          user:,
        )
      end

      it "changes access count" do
        expect { find_record }.to change { record.reload.use_count }.by(1)
      end
    end

    context "with no access_count change" do
      let(:access_count) { false }

      it "does not change access count" do
        expect { find_record }.to_not change { record.reload.use_count }
      end
    end

    context "when not found" do
      let(:input_secret) { "secret that does not exist" }

      it do
        expect(find_record).to eq(found: false)
      end
    end
  end

  describe "#invalid_reason" do
    subject(:invalid_reason) { record.invalid_reason }

    context "when dead" do
      let(:death_time) { 1.minute.ago }

      it do
        expect(invalid_reason).to include("Expired secret.")
      end
    end

    context "when overused" do
      let(:use_count_max) { -1 }

      it do
        expect(invalid_reason).to include("Secret used too many times.")
      end
    end

    context "when both" do
      let(:use_count_max) { -1 }
      let(:death_time) { 1.minute.ago }

      it do
        expect(invalid_reason).to include("Expired secret.", "Secret used too many times.")
      end
    end

    context "when valid" do
      it do
        expect(invalid_reason).to be_empty
      end
    end
  end

  describe "access_count!" do
    subject(:access_count) { record.access_count! }

    it do
      expect { access_count }.to change { record.reload.use_count }.by(1)
    end
  end

  describe "is_valid?" do
    subject(:is_valid) { record.is_valid? }

    it { is_expected.to eq(true) }

    context "when dead" do
      let(:death_time) { 1.minute.ago }

      it { is_expected.to eq(false) }
    end

    context "when overused" do
      let(:use_count_max) { -1 }

      it { is_expected.to eq(false) }
    end
  end

  describe "valid_use_count?" do
    subject(:valid_use_count) { record.valid_use_count? }

    it { is_expected.to eq(true) }

    context "when no max count present" do
      let(:use_count_max) { nil }

      it { is_expected.to eq(true) }
    end

    context "when overused" do
      let(:use_count_max) { -1 }

      it { is_expected.to eq(false) }
    end
  end

  describe "still_alive?" do
    subject(:still_alive) { record.still_alive? }

    it { is_expected.to eq(true) }

    context "when no death time present" do
      let(:death_time) { nil }

      it { is_expected.to eq(true) }
    end

    context "when dead" do
      let(:death_time) { 1.minute.ago }

      it { is_expected.to eq(false) }
    end
  end
end
