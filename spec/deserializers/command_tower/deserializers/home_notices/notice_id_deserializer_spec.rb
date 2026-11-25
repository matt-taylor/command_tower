# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::HomeNotices::NoticeIdDeserializer do
  describe ".call" do
    subject(:result) { described_class.call(params) }

    context "with a public id" do
      let(:params) { { id: "AbC123xyz" } }

      it "returns the public id only", :aggregate_failures do
        expect(result).to be_success
        expect(result.input.public_id).to eq("AbC123xyz")
        expect(result.input.campaign_key).to be_nil
      end
    end

    context "with a campaign id" do
      let(:params) { { "id" => "campaign:pickem.make_your_picks" } }

      it "returns the campaign key only", :aggregate_failures do
        expect(result).to be_success
        expect(result.input.campaign_key).to eq("pickem.make_your_picks")
        expect(result.input.public_id).to be_nil
      end
    end

    [nil, "", "   ", "campaign:", "campaign:Bad Key", "campaign:nodot", "has space", "x" * 33].each do |value|
      context "with #{value.inspect}" do
        let(:params) { { id: value } }

        it "fails" do
          expect(result).to be_failure
        end
      end
    end
  end
end
