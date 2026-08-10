# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::ClientIpResolver do
  describe ".call" do
    let(:request) { instance_double(ActionDispatch::Request, remote_ip: "203.0.113.5") }

    it "returns the request's remote_ip as a string" do
      expect(described_class.call(request: request)).to eq("203.0.113.5")
    end
  end
end
