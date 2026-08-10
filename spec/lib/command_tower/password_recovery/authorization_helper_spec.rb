# frozen_string_literal: true

RSpec.describe CommandTower::PasswordRecovery::AuthorizationHelper do
  describe ".extract_token" do
    subject(:extracted) { described_class.extract_token(request) }

    let(:request) { build_password_recovery_request(authorization: authorization) }

    context "without an Authorization header" do
      let(:authorization) { nil }

      it { is_expected.to eq(error: :missing) }
    end

    context "with a Recovery scheme token" do
      let(:authorization) { "Recovery some-token" }

      it { is_expected.to eq(token: "some-token") }
    end

    context "with a lowercase scheme" do
      let(:authorization) { "recovery some-token" }

      it { is_expected.to eq(token: "some-token") }
    end

    context "with a Bearer token" do
      let(:authorization) { "Bearer some-token" }

      it { is_expected.to eq(error: :invalid_format) }
    end

    context "with a Signup token" do
      let(:authorization) { "Signup some-token" }

      it { is_expected.to eq(error: :invalid_format) }
    end

    context "with a scheme but no token" do
      let(:authorization) { "Recovery   " }

      it { is_expected.to eq(error: :invalid_format) }
    end
  end
end
