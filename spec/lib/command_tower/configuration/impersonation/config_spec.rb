# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::Impersonation::Config do
  describe "#validate!" do
    subject(:config) { described_class.new }

    it "accepts the default idle and absolute timeouts" do
      expect(config.validate!).to eq(config)
      expect(config.idle_timeout).to eq(10.minutes)
      expect(config.absolute_timeout).to eq(1.hour)
    end

    context "when idle is not less than absolute" do
      before do
        config.idle_timeout = 1.hour
        config.absolute_timeout = 1.hour
      end

      it "raises" do
        expect { config.validate! }.to raise_error(ArgumentError, /idle_timeout must be less than absolute/)
      end
    end
  end
end
