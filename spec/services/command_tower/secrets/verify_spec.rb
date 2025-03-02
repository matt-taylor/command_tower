# frozen_string_literal: true

RSpec.describe CommandTower::Secrets::Verify do
  let(:generate) { CommandTower::Secrets::Generate.(**generate_params) }
  let(:generate_params) do
    {
      user:,
      secret_length: 10,
      reason:,
      use_count_max: 10,
    }
  end
  let(:user) { create(:user) }
  let(:reason) { CommandTower::Secrets::ALLOWED_SECRET_REASONS.sample }
  let(:secret) { generate.secret }
  let(:record) { generate.record }

  let(:input_secret) { secret }
  let(:params) { { secret: input_secret, reason: } }

  describe ".call" do
    subject(:call) { described_class.(**params) }

    it "succeeds" do
      expect(call.success?).to eq(true)
    end

    it "sets user" do
      expect(call.user).to eq(user)
    end

    context "when not found" do
      let(:input_secret) { "incorrect secret value" }

      it "fails" do
        expect(call.failure?).to eq(true)
      end

      it "sets message" do
        expect(call.msg).to eq("Secret not found")
      end

      it "does not set user" do
        expect(call.user).to be_nil
      end
    end

    context "when not valid" do
      before { record.update(use_count_max: -1) }

      it "fails" do
        expect(call.failure?).to eq(true)
      end

      it "sets message" do
        expect(call.msg).to include(/Secret is invalid/)
      end

      it "does not set user" do
        expect(call.user).to be_nil
      end

      it "deletes the record" do
        expect(described_class.(**params).msg).to include(/Secret is invalid/)

        expect(described_class.(**params).msg).to include(/Secret not found/)
      end

      context "when config deletes secret" do
        before { CommandTower.config.delete_secret_after_invalid = false }

        it "does not delete the record" do
          expect(described_class.(**params).msg).to include(/Secret is invalid/)

          expect(described_class.(**params).msg).to include(/Secret is invalid/)
        end
      end
    end
  end
end
