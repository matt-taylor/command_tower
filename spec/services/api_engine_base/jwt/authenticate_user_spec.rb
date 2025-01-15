# frozen_string_literal: true

RSpec.describe ApiEngineBase::Jwt::AuthenticateUser do
  let(:user) { create(:user) }
  let(:token) { ApiEngineBase::Jwt::LoginCreate.(user:).token }
  let(:payload) { { generated_at:, user_id:, verifier_token: } }
  let(:user_id) { user.id }
  let(:generated_at) { Time.now.to_i }
  let(:verifier_token) { user.retreive_verifier_token! }

  describe ".call" do
    subject(:call) { described_class.(token:) }

    it "succeeds" do
      expect(call.success?).to be(true)
    end

    it "sets user" do
      expect(call.user.id).to be(user.id)
    end

    context "with invalid user" do
      let(:token) { ApiEngineBase::Jwt::Encode.(payload:).token }
      let(:user_id) { 123456 }

      it "fails" do
        expect(call.failure?).to eq(true)
      end

      it "sets failure message" do
        expect(call.msg).to eq("Unauthorized Access. Invalid Authorization token")
      end
    end

    context "with invalid token" do
      let(:token) { "This is not a valid token" }

      it "fails" do
        expect(call.failure?).to eq(true)
      end

      it "sets failure message" do
        expect(call.msg).to eq("Unauthorized Access. Invalid Authorization token")
      end
    end

    context "with generated_at failure" do
      let(:token) { ApiEngineBase::Jwt::Encode.(payload:).token }

      context "with missing param" do
        let(:generated_at) { nil }

        it "fails" do
          expect(call.failure?).to eq(true)
        end

        it "sets failure message" do
          expect(call.msg).to eq("Unauthorized Access. Invalid Authorization token")
        end
      end

      context "with invalid param" do
        let(:generated_at) { "invalid param" }

        it "fails" do
          expect(call.failure?).to eq(true)
        end

        it "sets failure message" do
          expect(call.msg).to eq("Unauthorized Access. Invalid Authorization token")
        end
      end

      context "when expired" do
        let(:generated_at) { (ApiEngineBase.config.jwt.ttl - 1.day).to_i }

        it "fails" do
          expect(call.failure?).to eq(true)
        end

        it "sets failure message" do
          expect(call.msg).to eq("Unauthorized Access. Invalid Authorization token")
        end
      end
    end

    context "with mismatched verifier token" do
      let(:token) { ApiEngineBase::Jwt::Encode.(payload:).token }
      let(:verifier_token) { SecureRandom.alphanumeric(32) }

      it "fails" do
        expect(call.failure?).to eq(true)
      end

      it "sets failure message" do
        expect(call.msg).to eq("Unauthorized Access. Token is no longer valid")
      end
    end

    context "with email_verify" do
      before { ApiEngineBase.config.login.plain_text.email_verify.enable = email_verify }

      context "when enabled" do
        let(:email_verify) { true }

        context "with validated email" do
        end

        context "with invalid email" do
          before do
            user.update(created_at:)
          end
          let(:created_at) { 5.minutes.from_now }
          let(:user) { create(:user, :unvalidated_email) }

          it "succeeds" do
            expect(call.success?).to be(true)
          end

          it "sets user" do
            expect(call.user.id).to be(user.id)
          end

          context "when validation required" do
            let(:created_at) { 5.minutes.ago }

            it "fails" do
              expect(call.failure?).to be(true)
            end

            it "sets user" do
              expect(call.user.id).to be(user.id)
            end
          end
        end
      end

      context "when disabled" do
        let(:email_verify) { false }

        it "succeeds" do
          expect(call.success?).to be(true)
        end

        it "sets user" do
          expect(call.user.id).to be(user.id)
        end
      end
    end
  end
end
