# frozen_string_literal: true

RSpec.describe ApiEngineBase::AdminController, :with_rbac_setup, type: :controller do
  let(:response_body) { JSON.parse(response.body) }
  let(:user) { create(:user) }
  let(:user_id) { user.id }
  let(:admin_user) { create(:user, :role_admin) }

  shared_examples "with invalid user to modify" do
    context "when input user is invalid" do
      let(:user_id) { "DNE" }

      it "sets 400 status" do
        subject

        expect(response.status).to eq(400)
      end

      it "sets message" do
        subject

        expect(response_body["message"]).to include("Invalid user")
      end
    end
  end

  describe "GET: show" do
    subject(:show) { get(:show) }

    let(:user_count) { rand(5..10) }
    before do
      create_list(:user, user_count)
      set_jwt_token!(user: admin_user)
    end

    context "with before action failures" do
      let(:admin_user) { create(:user) }

      include_examples "Invalid/Missing JWT token on required route"
      include_examples "UnAuthorized Access on Controller Action"
    end

    it "returns 200" do
      subject

      expect(response.status).to eq(200)
    end

    it "returns correct user count" do
      subject

      expect(response_body["users"].length).to eq(user_count + 1)
    end

    it "returns user array" do
      subject

      expect(response_body["users"]).to all(include(*ApiEngineBase::Schema::User.introspect.keys))
    end
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

    before { set_jwt_token!(user: admin_user) }

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

    context "with before action failures" do
      let(:admin_user) { create(:user) }

      include_examples "Invalid/Missing JWT token on required route"
      include_examples "UnAuthorized Access on Controller Action"
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
      include_examples "with invalid user to modify"
    end

    context "with username" do
      let(:username) { value }
      let(:value) { "thisIsMyUsername1" }

      include_examples "Modify User Attribute shared example", :username
      include_examples "with invalid user to modify"
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

      include_examples "with invalid user to modify"
    end

    context "with first_name" do
      let(:first_name) { value }
      let(:value) { "This is My new First Name" }

      include_examples "Modify User Attribute shared example", :first_name
      include_examples "with invalid user to modify"
    end

    context "with last_name" do
      let(:last_name) { value }
      let(:value) { "This is My new Last Name" }

      include_examples "Modify User Attribute shared example", :last_name
      include_examples "with invalid user to modify"
    end
  end

  describe "POST: modify_role" do
    subject(:modify_role) { post(:modify_role, params:) }

    let(:params) { { user_id:, roles: }.compact }
    let(:roles) { ["admin"] }
    let(:user_id) { user.id }
    before { set_jwt_token!(user: admin_user) }

    context "with before action failures" do
      let(:admin_user) { create(:user) }

      include_examples "Invalid/Missing JWT token on required route"
      include_examples "UnAuthorized Access on Controller Action"
    end

    context "with invalid parameters" do
      let(:roles) { ["invalid role name"] }

      include_examples "with invalid user to modify"
      include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, " roles: Invalid roles provided", :roles
    end

    it "returns 201" do
      subject

      expect(response.status).to eq(201)
    end

    it "sets new role" do
      subject
    end

    it "returns new user keys" do
      subject

      expect(response_body["roles"]).to include(*roles)
    end
  end
end
