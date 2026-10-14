# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Preferences::PreferenceState do
  describe ".normalize" do
    subject(:state) { described_class.normalize(raw) }

    context "with channels only" do
      let(:raw) { { "channels" => { "email" => false }, "inbox" => true } }

      it "round-trips without urgency or sound" do
        expect(state.urgency).to be_nil
        expect(state.sound).to be_nil
        expect(state.to_raw_hash).to eq("channels" => { "email" => false }, "inbox" => true)
      end
    end

    context "with urgency and sound" do
      let(:raw) { { "urgency" => " time_sensitive ", "sound" => "chime", "channels" => {} } }

      it "keeps stripped strings and omits empty channels from the raw hash keys that are nil" do
        expect(state.urgency).to eq("time_sensitive")
        expect(state.sound).to eq("chime")
        expect(state.to_raw_hash).to eq(
          "channels" => {},
          "urgency" => "time_sensitive",
          "sound" => "chime",
        )
      end
    end

    context "with a blank urgency" do
      let(:raw) { { "urgency" => "  ", "channels" => { "email" => true } } }

      it "drops the blank value" do
        expect(state.urgency).to be_nil
        expect(state.to_raw_hash).not_to have_key("urgency")
      end
    end

    context "with an empty hash" do
      let(:raw) { {} }

      it "is a reset" do
        expect(state).to be_nil
      end
    end
  end
end
