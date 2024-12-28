RSpec.describe ApiEngineBase::Auth::PlainTextController, type: :controller do

  before do
    # create some users in the system
    10.times { create(:user)}
  end

  let(:fake_user) { build(:user, :unvalidated_email, password:) }
  let(:password) { Faker::Alphanumeric.alpha(number: 20) }
  let(:user_params) do
    {
      first_name: fake_user.first_name,
      last_name: fake_user.last_name,
      username: fake_user.username,
      email: fake_user.email,
      password: password,
      password_confirmation: password,
    }
  end

  it "create user, login, and validate email" do
    ####
    # Create a new user with missing params
    post(:create_post, params: {})
    expect(response.status).to eq(400)

    ####
    # Create a new user
    post(:create_post, params: user_params)
    expect(response.status).to eq(201)

    ####
    # Request Email verification without signing in
    post(:email_verify_resend_post)
    expect(response.status).to eq(401)

    ####
    # Sign in via username and validate token
    post(:login_post, params: { username: fake_user.username, password: })
    expect(response.status).to eq(201)
    login_post_response = JSON.parse(response.body)
    login_post_jwt_username = ApiEngineBase::Jwt::AuthenticateUser.(token: login_post_response["token"], bypass_email_validation: true)
    expect(login_post_jwt_username.success?).to be(true)

    ####
    # Sign in via email and validate token
    post(:login_post, params: { email: fake_user.email, password: })
    expect(response.status).to eq(201)
    login_post_response = JSON.parse(response.body)
    login_post_jwt_email = ApiEngineBase::Jwt::AuthenticateUser.(token: login_post_response["token"], bypass_email_validation: true)
    expect(login_post_jwt_email.success?).to be(true)

    ####
    # Users returned via username login and email login are the same
    expect(login_post_jwt_email.user).to eq(login_post_jwt_username.user)

    # They are the same so reduce for simplicity
    login_post_jwt = login_post_jwt_email

    ####
    # Request Email verification without passing in JWT token
    unset_jwt_token!
    user = login_post_jwt.user
    post(:email_verify_resend_post)
    expect(response.status).to eq(401)

    ####
    # Request Email verification and pass in JWT token
    user = login_post_jwt.user
    set_jwt_token!(user:, token: login_post_response["token"])
    post(:email_verify_resend_post)
    expect(response.status).to eq(201)

    unset_jwt_token!

    ####
    # Validate Email using code fails after unsetting jwt token
    code = UserSecret.last.secret
    post(:email_verify_post, params: { code: })
    expect(response.status).to eq(401)

    ####
    # Validate Email using code fails after unsetting jwt token
    set_jwt_token!(user:, token: login_post_response["token"])
    code = UserSecret.last.secret
    post(:email_verify_post, params: { code: })
    expect(response.status).to eq(201)
  end
end
