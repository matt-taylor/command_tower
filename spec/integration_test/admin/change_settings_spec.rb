# frozen_string_literal: true

RSpec.describe ApiEngineBase::AdminController, :with_rbac_setup, type: :controller do
  before do
    # create some users in the system
    10.times { create(:user) }
  end

  let!(:user) { create(:user) }
  let(:admin_user) { create(:user, :role_admin) }
  let(:response_body) { JSON.parse(response.body) }

  it "validate Admin RBAC and validate changes users value hold" do
    ##
    # JWT token was not set
    get(:show)
    expect(response.status).to eq(401)

    ####
    # Does Not set the Expire Time on the header
    expect(response.headers[ApiEngineBase::ApplicationController::AUTHENTICATION_EXPIRE_HEADER.downcase]).to be_nil

    ##
    # User is not authorized to make the call
    set_jwt_token!(user: user)
    get(:show)
    expect(response.status).to eq(403)

    ####
    # Sets the Expire Time on the header
    expire_time = response.headers[ApiEngineBase::ApplicationController::AUTHENTICATION_EXPIRE_HEADER.downcase]
    expect(Time.parse(expire_time)).to be_within(1.second).of(ApiEngineBase.config.jwt.ttl.from_now)

    ##
    # User is authorized to make the call
    set_jwt_token!(user: admin_user)
    get(:show)
    expect(response.status).to eq(200)

    ##
    # It returns the user we are looking for
    users_response = JSON.parse(response.body)["users"]
    user_json = users_response.find { _1["id"] == user.id }
    expect(user.email).to eq(user_json["email"])
    expect(user.first_name).to eq(user_json["first_name"])
    expect(user.last_name).to eq(user_json["last_name"])
    expect(user.username).to eq(user_json["username"])

    ####
    # Sets the Expire Time on the header
    expire_time = response.headers[ApiEngineBase::ApplicationController::AUTHENTICATION_EXPIRE_HEADER.downcase]
    expect(Time.parse(expire_time)).to be_within(1.second).of(ApiEngineBase.config.jwt.ttl.from_now)

    ##
    # Update to an invalid email!
    bad_email = "This is not a Valid email Addy"
    post(:modify, params: { user_id: user_json["id"], email: bad_email } )
    modify_response = JSON.parse(response.body)
    expect(response.status).to eq(400)
    expect(modify_response["invalid_argument_keys"]).to include("email")

    ##
    # Update to an valid email
    valid_email = Faker::Internet.email
    post(:modify, params: { user_id: user_json["id"], email: valid_email } )
    user_json = JSON.parse(response.body)
    expect(valid_email).to eq(user_json["email"])
    expect(user.reload.email).to eq(user_json["email"])
    expect(user.first_name).to eq(user_json["first_name"])
    expect(user.last_name).to eq(user_json["last_name"])
    expect(user.username).to eq(user_json["username"])

    ##
    # Update to an invalid Role
    bad_role = ["This is not a Valid role"]
    post(:modify_role, params: { user_id: user_json["id"], roles: bad_role } )
    modify_response = JSON.parse(response.body)
    expect(response.status).to eq(400)
    expect(modify_response["invalid_argument_keys"]).to include("roles")

    ##
    # Update to an Multiple Valid Roles
    roles = ApiEngineBase::Authorization::Role.roles.keys
    post(:modify_role, params: { user_id: user_json["id"], roles: } )
    expect(response.status).to eq(201)

    user_json = JSON.parse(response.body)
    expect(valid_email).to eq(user_json["email"])
    expect(user.reload.email).to eq(user_json["email"])
    expect(user.first_name).to eq(user_json["first_name"])
    expect(user.last_name).to eq(user_json["last_name"])
    expect(roles.map(&:to_s)).to eq(user_json["roles"])

    ##
    # User with new roles can now view admin
    set_jwt_token!(user: user)
    get(:show)
    expect(response.status).to eq(200)

    ##
    # Remove roles on user
    set_jwt_token!(user: admin_user)
    roles = []
    post(:modify_role, params: { user_id: user.id, roles: })
    user_json = JSON.parse(response.body)
    expect(response.status).to eq(201)
    expect([]).to eq(user_json["roles"])

    ##
    # User can no longer see admin routes
    set_jwt_token!(user: user)
    get(:show)
    expect(response.status).to eq(403)
  end
end
