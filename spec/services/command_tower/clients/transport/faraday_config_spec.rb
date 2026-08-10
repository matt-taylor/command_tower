# frozen_string_literal: true

RSpec.describe CommandTower::Clients::Transport::FaradayConfig do
  describe ".defaults" do
    subject(:config) { described_class.defaults }

    it "returns the documented default values" do
      expect(config).to eq(described_class.new(pool_size: 5, idle_timeout: 30, open_timeout: 5, timeout: 30))
    end
  end

  describe ".from_env" do
    around do |example|
      original_env = ENV.to_h
      example.run
      ENV.replace(original_env)
    end

    it "falls back to defaults when env vars are unset" do
      %w[CLIENTS_HTTP_POOL_SIZE CLIENTS_HTTP_IDLE_TIMEOUT CLIENTS_HTTP_OPEN_TIMEOUT CLIENTS_HTTP_TIMEOUT].each do |key|
        ENV.delete(key)
      end

      expect(described_class.from_env).to eq(described_class.defaults)
    end

    context "when env vars are set" do
      subject(:config) { described_class.from_env }

      before do
        ENV["CLIENTS_HTTP_POOL_SIZE"] = "10"
        ENV["CLIENTS_HTTP_IDLE_TIMEOUT"] = "60"
        ENV["CLIENTS_HTTP_OPEN_TIMEOUT"] = "2"
        ENV["CLIENTS_HTTP_TIMEOUT"] = "45"
      end

      it "reads integer values from the environment" do
        expect(config).to eq(described_class.new(pool_size: 10, idle_timeout: 60, open_timeout: 2, timeout: 45))
      end
    end
  end
end
