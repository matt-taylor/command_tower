# frozen_string_literal: true

RSpec.describe ApiEngineBase::Secrets::Cleanse do
  let(:user) { create(:user) }
  let(:params) do
    {
      user:,
      reason:,
    }
  end
  let(:reason) { ApiEngineBase::Secrets::ALLOWED_SECRET_REASONS.sample }

  describe ".call" do
    subject(:call) { described_class.call(**params) }

    it do
      expect { call }.to change(UserSecret, :count).by(0)
    end

    context "with existing secrets with same reason" do
      before do
        ApiEngineBase::Secrets::Generate.call(
          user: used_user,
          secret_length: 20,
          reason:,
          type: ApiEngineBase::Secrets::ALLOWED_SECRET_TYPES.sample,
          death_time: 5.minutes,
        )
      end

      let(:used_user) { user }

      it do
        expect { call }.to change(UserSecret, :count).by(-1)
      end

      context "with different user" do
        let(:used_user) { create(:user) }

        it do
          expect { call }.to change(UserSecret, :count).by(0)
        end
      end
    end

    context "with existing secrets with different reasons" do
      before do
        ApiEngineBase::Secrets::Generate.call(
          user:,
          secret_length: 20,
          reason: reason2,
          type: ApiEngineBase::Secrets::ALLOWED_SECRET_TYPES.sample,
          death_time: 5.minutes,
        )
      end

      let(:reason) { ApiEngineBase::Secrets::ALLOWED_SECRET_REASONS[0] }
      let(:reason2) { ApiEngineBase::Secrets::ALLOWED_SECRET_REASONS[1] }

      it do
        expect { call }.to change(UserSecret, :count).by(0)
      end
    end
  end
end
