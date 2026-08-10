# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Messaging::Preferences::UpdateDeserializer do
  describe "#call" do
    context "with a valid preference update" do
      subject(:result) do
        described_class.call(
          notification_type_key: "booking_confirmation",
          preferences: {
            "inboxEnabled" => false,
            "channels" => { "email" => false },
          },
        )
      end

      it "parses a valid preference update" do
        expect(result).to be_success
        expect(result.input.notification_type_key).to eq("booking_confirmation")
        expect(result.input.preference_state).to eq(
          "inbox" => false,
          "channels" => { "email" => false },
        )
      end
    end

    context "with an empty preferences object" do
      subject(:result) do
        described_class.call(
          notification_type_key: "booking_confirmation",
          preferences: {},
        )
      end

      it "treats an empty preferences object as reset" do
        expect(result).to be_success
        expect(result.input.preference_state).to eq({})
      end
    end

    context "when preferences are missing" do
      subject(:result) { described_class.call(notification_type_key: "booking_confirmation") }

      it "rejects missing preferences" do
        expect(result).to be_failure
      end
    end

    context "with unexpected top-level fields" do
      subject(:result) do
        described_class.call(
          notification_type_key: "booking_confirmation",
          preferences: { "inboxEnabled" => true },
          label: "nope",
        )
      end

      it "rejects unexpected top-level fields" do
        expect(result).to be_failure
      end
    end

    context "with unexpected preference fields" do
      subject(:result) do
        described_class.call(
          notification_type_key: "booking_confirmation",
          preferences: { "mandatory" => true },
        )
      end

      it "rejects unexpected preference fields" do
        expect(result).to be_failure
      end
    end

    context "with non-boolean channel values" do
      subject(:result) do
        described_class.call(
          notification_type_key: "booking_confirmation",
          preferences: { "channels" => { "email" => "false" } },
        )
      end

      it "rejects non-boolean channel values" do
        expect(result).to be_failure
      end
    end

    context "with a blank notification type key" do
      subject(:result) do
        described_class.call(
          notification_type_key: "  ",
          preferences: {},
        )
      end

      it "rejects a blank notification type key" do
        expect(result).to be_failure
      end
    end
  end
end
