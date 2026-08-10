# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Me::ChangePasswordDeserializer do
  describe ".call" do
    subject(:result) { described_class.call(params) }

    context "with camelCase fields" do
      let(:params) do
        {
          currentPassword: "old",
          password: "newpassword1234",
          passwordConfirmation: "newpassword1234"
        }
      end

      it "succeeds" do
        expect(result).to be_success
        expect(result.input.current_password).to eq("old")
      end
    end

    context "with missing fields" do
      let(:params) { { currentPassword: "old" } }

      it "fails" do
        expect(result).not_to be_success
      end
    end
  end
end
