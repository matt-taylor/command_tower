# frozen_string_literal: true

RSpec.describe CommandTower::LoginStrategy::PlainText::Login do
  let(:user) { create(:user, password:) }
  let(:password) { Faker::Alphanumeric.alpha(number: 20) }
  let(:password_input) { password }
  let(:email) { user.email }
  let(:username) { user.username }

  describe ".call" do
    subject(:call) { described_class.(**payload) }

    shared_examples "with incorrect credentials" do
      context "with incorrect identifier" do
        let(:payload) { super().merge(identifier: "This is an Incorrect Value") }
        let(:message) { "Unauthorized Access. Incorrect Credentials" }
        it "fails" do
          expect(call.failure?).to be(true)
        end

        it "does not change user login count" do
          expect { call }.not_to change { user.reload.successful_login }
        end

        it "returns correct messaging" do
          expect(call.msg).to include(message)
        end

        it "sets invalid_arguments correct messaging" do
          expect(call.invalid_arguments).to eq(true)
        end

        it "sets invalid_argument_hash" do
          expect(call.invalid_argument_hash).to include(
            identifier: { msg: /#{message}/ }
          )
        end
      end

      context "with incorrect password" do
        let(:payload) { super().merge(password: "This is an Incorrect Value") }

        it "fails" do
          expect(call.failure?).to eq(true)
        end

        it "returns messaging" do
          expect(call.msg).to include("Unauthorized Access. Incorrect Credentials")
        end

        it "sets invalid_argument_hash" do
          expect(call.invalid_argument_hash).to include(
            identifier: { msg: /Unauthorized Access. Incorrect Credentials/ }
          )
        end

        it "sets invalid_argument_keys" do
          expect(call.invalid_argument_keys).to include(:identifier)
        end

        it "increases failed count" do
          expect { call }.to change { user.reload.password_consecutive_fail }.by(1)
        end
      end
    end

    shared_examples "with valid credentials" do
      it "succeeds" do
        expect(call.success?).to eq(true)
      end

      it "sets token" do
        expect(call.token).to be_present
      end

      it "increases login success" do
        expect { call }.to change { user.reload.successful_login }.by(1)
      end

      it "resets password_consecutive_fail" do
        call

        expect(user.reload.password_consecutive_fail).to eq(0)
      end
    end

    context "with identifier" do
      context "when identifier is username" do
        let(:payload) { { identifier: username, password: } }

        include_examples "with valid credentials"
        include_examples "with incorrect credentials"
      end

      context "when identifier is email" do
        let(:payload) { { identifier: email, password: } }

        include_examples "with valid credentials"
        include_examples "with incorrect credentials"
      end
    end
  end
end
