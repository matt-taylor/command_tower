# frozen_string_literal: true

# Service-layer journey: register → login → email verify.
# HTTP contracts live under spec/requests/command_tower/auth/ (register, login, email_verification).
RSpec.describe "Plain text auth email verification journey" do
  before do
    # create some users in the system
    10.times { create(:user) }
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
    # Register
    missing = CommandTower::Services::Auth::Register.call(**user_params.transform_values { nil })
    expect(missing.failure?).to be(true)

    created = CommandTower::Services::Auth::Register.call(**user_params)
    expect(created.success?).to be(true)

    ####
    # Sign in via username
    login_username = CommandTower::Services::Auth::PlainText::Login.call(
      identifier: fake_user.username,
      password:
    )
    expect(login_username.success?).to be(true)
    login_post_jwt_username = CommandTower::Jwt::AuthenticateUser.(
      token: login_username.data[:token],
      bypass_email_validation: true
    )
    expect(login_post_jwt_username.success?).to be(true)

    ####
    # Sign in via email
    login_email = CommandTower::Services::Auth::PlainText::Login.call(
      identifier: fake_user.email,
      password:
    )
    expect(login_email.success?).to be(true)
    login_post_jwt_email = CommandTower::Jwt::AuthenticateUser.(
      token: login_email.data[:token],
      bypass_email_validation: true
    )
    expect(login_post_jwt_email.success?).to be(true)

    ####
    # Users returned via username login and email login are the same
    expect(login_post_jwt_email.user).to eq(login_post_jwt_username.user)
    user = login_post_jwt_email.user
    expect(user.email_validated).to be(false)

    ####
    # Request email verification
    send_result = CommandTower::Services::Auth::EmailVerification::Send.call(user:)
    expect(send_result.success?).to be(true)

    ####
    # Validate email using code
    code = UserSecret.last.secret
    verify_result = CommandTower::Services::Auth::EmailVerification::Verify.call(user:, code:)
    expect(verify_result.success?).to be(true)
    expect(user.reload.email_validated).to be(true)
  end
end
