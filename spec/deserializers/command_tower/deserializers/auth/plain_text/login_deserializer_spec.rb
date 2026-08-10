# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Auth::PlainText::LoginDeserializer do
  describe ".call" do
    subject(:result) { described_class.call(params) }

    context "with valid params" do
      let(:params) { { identifier: "  user@example.com ", password: "  secret  " } }

      it "strips and returns input" do
        expect(result).to be_success
        expect(result.input.identifier).to eq("user@example.com")
        expect(result.input.password).to eq("secret")
      end
    end

    context "with blank identifier" do
      let(:params) { { identifier: " ", password: "secret" } }

      it "fails with invalid_credentials marker" do
        expect(result).to be_failure
        expect(result.errors).to include(hash_including(message: "invalid_credentials"))
      end
    end
  end
end
