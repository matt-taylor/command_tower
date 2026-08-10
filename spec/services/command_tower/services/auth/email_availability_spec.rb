# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::EmailAvailability do
  describe ".call" do
    subject(:result) { described_class.call(email: email) }

    context "with an available email" do
      let(:email) { "svc-email-available@example.com" }

      it "returns valid and available" do
        expect(result).to be_success
        expect(result.data).to include(valid: true, available: true, message: "Email is available")
      end
    end

    context "with an existing email" do
      let!(:user) { create(:user, email: "svc-email-taken@example.com", username: "svcemailtaken") }
      let(:email) { "svc-email-taken@example.com" }

      it "returns valid but unavailable" do
        expect(result).to be_success
        expect(result.data).to include(
          valid: true,
          available: false,
          message: "Email is already registered"
        )
      end
    end

    context "with an invalid email format" do
      let(:email) { "not-an-email" }

      before { allow(::User).to receive(:exists?).and_call_original }

      it "returns invalid" do
        expect(result).to be_success
        expect(result.data).to include(valid: false, available: false)
      end

      it "does not query persistence" do
        result
        expect(::User).not_to have_received(:exists?)
      end
    end

    context "with mixed case and surrounding whitespace" do
      let!(:user) { create(:user, email: "svc-email-case@example.com", username: "svcemailcase") }
      let(:email) { "  Svc-Email-Case@Example.com  " }

      it "normalizes before checking availability" do
        expect(result.data).to include(valid: true, available: false)
      end
    end

    context "when email is missing" do
      subject(:result) { described_class.call(email: nil) }

      it "returns a ValidationError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::ValidationError))
      end
    end
  end
end
