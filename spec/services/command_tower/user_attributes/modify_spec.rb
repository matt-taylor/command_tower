# frozen_string_literal: true

RSpec.describe CommandTower::UserAttributes::Modify do
  let(:user) { create(:user) }
  let(:admin_user) { nil }
  let(:params) do
    {
      user:,
      admin_user:,
      email:,
      email_validated:,
      first_name:,
      last_name:,
      username:,
      verifier_token:,
    }.compact
  end
  let(:email) { nil }
  let(:email_validated) { nil }
  let(:first_name) { nil }
  let(:last_name) { nil }
  let(:username) { nil }
  let(:verifier_token) { nil }

  describe ".call" do
    subject(:call) { described_class.(**params) }

    context "with special values" do
      shared_examples "modify special attribute sharable" do |attribute, success, failed|
        context "with #{attribute}" do
          let(attribute) { success }
          it "succeeds" do
            expect(call.success?).to be(true)
          end

          it "changes value" do
            expect { call }.to change { user.reload.public_send(attribute) }.to(success)
          end

          context "when invalid" do
            let(attribute) { failed }

            it "fails" do
              expect(call.failure?).to be(true)
            end

            it "sets context values" do
              expect(call.msg).to include("Invalid arguments: #{attribute}")
              expect(call.invalid_argument_keys).to eq([attribute])
              expect(call.invalid_arguments).to be(true)
            end

            it "does not change value" do
              expect { call }.to_not change { user.reload.public_send(attribute) }
            end
          end
        end
      end

      include_examples "modify special attribute sharable", :email, Faker::Internet.email, "this is not a valid email"
      include_examples "modify special attribute sharable", :username, "thisIsAUserName12", "1"

      context "with verifier_token" do
        let(:verifier_token) { true }
        it "succeeds" do
          expect(call.success?).to be(true)
        end

        it "changes verifier_token" do
          expect { call }.to change { user.reload.verifier_token }
        end

        it "changes verifier_token_last_reset" do
          expect { call }.to change { user.reload.verifier_token_last_reset }
        end

        context "when invalid" do
          let(:verifier_token) { false }

          it "fails" do
            expect(call.failure?).to be(true)
          end

          it "sets context values" do
            expect(call.msg).to include("Invalid arguments: verifier_token")
            expect(call.invalid_argument_keys).to eq([:verifier_token])
            expect(call.invalid_arguments).to be(true)
          end

          it "does not change value" do
            expect { call }.to_not change { user.reload.verifier_token }
          end
        end
      end
    end

    context "with unspecial attribute" do
      let(:first_name) { "This is a new First Name" }

      it "succeeds" do
        expect(call.success?).to be(true)
      end

      it "changes value" do
        expect { call }.to change { user.reload.public_send(:first_name) }.to(first_name)
      end
    end
  end
end
