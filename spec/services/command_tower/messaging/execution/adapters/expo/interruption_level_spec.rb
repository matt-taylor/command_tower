# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Execution::Adapters::Expo::InterruptionLevel do
  describe ".call" do
    {
      %w[normal] => { "normal" => nil, "time_sensitive" => nil, "critical" => nil },
      %w[normal time_sensitive] => {
        "normal" => nil, "time_sensitive" => "time-sensitive", "critical" => "time-sensitive"
      },
      %w[normal time_sensitive critical] => {
        "normal" => nil, "time_sensitive" => "time-sensitive", "critical" => "critical"
      },
      %w[normal critical] => { "normal" => nil, "time_sensitive" => nil, "critical" => "critical" },
      [] => { "normal" => nil, "time_sensitive" => nil, "critical" => nil },
    }.each do |supported, expectations|
      context "when the host supports #{supported.inspect}" do
        expectations.each do |urgency, expected|
          it "maps #{urgency} to #{expected.inspect}" do
            expect(described_class.call(urgency:, supported:)).to eq(expected)
          end
        end
      end
    end

    it "sends no level for an unknown urgency" do
      expect(described_class.call(urgency: "loud", supported: %w[normal time_sensitive critical])).to be_nil
    end

    it "accepts symbols" do
      expect(described_class.call(urgency: :time_sensitive, supported: [:time_sensitive])).to eq("time-sensitive")
    end
  end
end
