# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::NotificationPreference do
  describe "factory" do
    subject(:preference) { create(:messaging_notification_preference) }

    it "is valid" do
      expect(preference).to be_persisted
      expect(preference.user).to be_present
      expect(preference.notification_type_key).to eq("example.type")
      expect(preference.state).to include("inbox" => true)
    end
  end

  describe "associations and validations" do
    subject(:preference) { build(:messaging_notification_preference, user:, notification_type_key:, state:) }

    let(:user) { create(:user) }
    let(:notification_type_key) { "booking.success" }
    let(:state) { { "channels" => { "email" => true }, "inbox" => true } }

    it "belongs to user" do
      expect(preference.user).to eq(user)
    end

    context "when notification_type_key is blank" do
      let(:notification_type_key) { "" }

      it "is invalid" do
        expect(preference).not_to be_valid
        expect(preference.errors[:notification_type_key]).to be_present
      end
    end

    context "when state is blank" do
      let(:state) { nil }

      it "is invalid" do
        expect(preference).not_to be_valid
        expect(preference.errors[:state]).to be_present
      end
    end

    context "when notification_type_key is already taken for the user" do
      before do
        create(
          :messaging_notification_preference,
          user:,
          notification_type_key: "booking.success",
        )
      end

      it "is invalid" do
        expect(preference).not_to be_valid
        expect(preference.errors[:notification_type_key]).to be_present
      end
    end

    context "when the same key belongs to another user" do
      before do
        create(
          :messaging_notification_preference,
          user: create(:user),
          notification_type_key: "booking.success",
        )
      end

      it "is valid" do
        expect(preference).to be_valid
      end
    end
  end

  describe ".find_for" do
    subject(:found) do
      described_class.find_for(recipient_id: user.id, notification_type_key: "booking.success")
    end

    let(:user) { create(:user) }

    context "when a matching preference exists" do
      let!(:preference) do
        create(
          :messaging_notification_preference,
          user:,
          notification_type_key: "booking.success",
        )
      end

      it "returns the preference" do
        expect(found).to eq(preference)
      end
    end

    context "when no matching preference exists" do
      it "returns nil" do
        expect(found).to be_nil
      end
    end
  end
end
