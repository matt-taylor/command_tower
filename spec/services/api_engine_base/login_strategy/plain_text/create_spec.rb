# frozen_string_literal: true

RSpec.describe ApiEngineBase::LoginStrategy::PlainText::Create do
  let(:first_name) { Faker::Name.first_name  }
  let(:last_name) { Faker::Name.last_name  }
  let(:username) { build(:user).username }
  let(:email) { Faker::Internet.email }
  let(:password) do
    min = ApiEngineBase.config.login.plain_text.password_length_min + 1
    max = ApiEngineBase.config.login.plain_text.password_length_max - 1

    SecureRandom.alphanumeric(rand(min...max))
  end
  let(:password_confirmation) { password }
  let(:payload) do
    {
      first_name:,
      last_name:,
      username:,
      email:,
      password:,
      password_confirmation:,
    }
  end

  describe ".call" do
    subject(:call) { described_class.(**payload) }

    it "succeeds" do
      expect(call.success?).to be(true)
    end

    it "saves user to db" do
      expect { call }.to change(User, :count).by(1)
    end

    it "passes back user" do
      expect(call.user).to be_a(User)
    end

    shared_examples "with invalid inline arguments" do |argument, message|
      it "fails" do
        expect(call.failure?).to be(true)
      end

      it "does not save user to db" do
        expect { call }.not_to change(User, :count)
      end

      it "returns correct messaging" do
        expect(call.msg).to include(message)
      end

      it "sets invalid_arguments correct messaging" do
        expect(call.invalid_arguments).to eq(true)
      end

      it "sets invalid_argument_hash" do
        expect(call.invalid_argument_hash).to include(
          argument => { msg: /#{message}/ }
        )
      end
    end

    context "with incorrect password confirmation" do
      let(:password_confirmation) { "incorrect validation" }

      include_examples "with invalid inline arguments", :password_confirmation, "doesn't match Password"
    end

    context "with duplicate email" do
      let!(:user) { create(:user) }
      let(:email) { user.email }

      include_examples "with invalid inline arguments", :email, "has already been taken"
    end

    context "with invalid email" do
      let(:email) { "not an email addy" }

      include_examples "with invalid inline arguments", :email, "Invalid email address"
    end

    context "with duplicate username" do
      let!(:user) { create(:user) }
      let(:username) { user.username }

      include_examples "with invalid inline arguments", :username, "has already been taken"
    end

    context "with invalid username" do
      let(:username) { "this is invalid" }

      include_examples "with invalid inline arguments", :username, "Username is invalid"
    end
  end
end
