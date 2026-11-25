# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Admin::HomeNotices::ControlDeserializer do
  describe ".call" do
    subject(:result) { described_class.call(params) }

    [true, false].each do |value|
      context "with enabled #{value}" do
        let(:params) { { key: "pickem.make_your_picks", enabled: value } }

        it "returns the key and flag", :aggregate_failures do
          expect(result).to be_success
          expect(result.input.key).to eq("pickem.make_your_picks")
          expect(result.input.enabled).to be(value)
        end
      end
    end

    context "with string-keyed params" do
      let(:params) { { "key" => "ct.update_app", "enabled" => false } }

      it "succeeds" do
        expect(result.input.key).to eq("ct.update_app")
      end
    end

    [nil, "", "  ", "Bad Key", "has space", "a..b", "x" * 129].each do |value|
      context "with key #{value.inspect}" do
        let(:params) { { key: value, enabled: true } }

        it "fails" do
          expect(result).to be_failure
        end
      end
    end

    [nil, "false", "true", 0, 1, "yes"].each do |value|
      context "with enabled #{value.inspect}" do
        let(:params) { { key: "a.b", enabled: value } }

        it "fails (a strict boolean is required)" do
          expect(result).to be_failure
        end
      end
    end
  end
end
