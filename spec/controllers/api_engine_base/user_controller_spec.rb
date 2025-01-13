# frozen_string_literal: true

RSpec.describe ApiEngineBase::UserController, :with_rbac_setup, type: :controller do
  let(:response_body) { JSON.parse(response.body) }
  let(:user) { create(:user) }
  let(:user_id) { user.id }

  before { set_jwt_token!(user:) }

  describe "GET: show" do
    subject(:show) { get(:show) }

    it "returns 200" do
      subject

      expect(response.status).to eq(200)
    end

    it "returns user values" do
      subject

      expect(response_body).to include(*ApiEngineBase::Schema::User.introspect.keys)
    end

    include_examples "Invalid/Missing JWT token on required route"
  end

  describe "POST: modify" do
    subject(:modify) { post(:modify, params:) }

    let(:params) do
      {
        user_id:,
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

    before { set_jwt_token!(user:) }

    shared_examples "Modify User Attribute shared example" do |key|
      it "returns 201" do
        subject

        expect(response.status).to eq(201)
      end

      it "returns new user keys" do
        subject

        expect(response_body.keys).to include(*ApiEngineBase::Schema::User.introspect.keys)
      end

      it "has correct key change" do
        subject

        expect(response_body[key.to_s]).to eq(value)
      end
    end

    context "with invalid parameters" do
      context "with email" do
        let(:email) { "not a valid email" }
        include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, "Invalid email address", :email
      end

      context "with username" do
        let(:username) { "x" }
        include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, "Username is invalid", :username
      end

      context "with verifier_token" do
        context "when false" do
          let(:verifier_token) { false }

          include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, "verifier_token is invalid", :verifier_token
        end

        context "when 0" do
          let(:verifier_token) { 0 }

          include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, "verifier_token is invalid", :verifier_token
        end
      end
    end

    context "with email" do
      let(:email) { value }
      let(:value) { Faker::Internet.email }

      include_examples "Modify User Attribute shared example", :email
    end

    context "with username" do
      let(:username) { value }
      let(:value) { "thisIsMyUsername1" }

      include_examples "Modify User Attribute shared example", :username
    end

    context "with verifier_token" do
      let(:verifier_token) { value }
      let(:value) { true }

      it "returns 201" do
        subject

        expect(response.status).to eq(201)
      end

      it "returns new user keys" do
        subject

        expect(response_body.keys).to include(*ApiEngineBase::Schema::User.introspect.keys)
      end
    end

    context "with first_name" do
      let(:first_name) { value }
      let(:value) { "This is My new First Name" }

      include_examples "Modify User Attribute shared example", :first_name
    end

    context "with last_name" do
      let(:last_name) { value }
      let(:value) { "This is My new Last Name" }

      include_examples "Modify User Attribute shared example", :last_name
    end

    include_examples "Invalid/Missing JWT token on required route"
  end
end
