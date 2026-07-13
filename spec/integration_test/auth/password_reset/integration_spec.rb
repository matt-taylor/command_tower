# frozen_string_literal: true

RSpec.describe CommandTower::Auth::PlainTextController, type: :controller do
  let(:fake_user) { build(:user, password:) }
  let(:password) { Faker::Alphanumeric.alpha(number: 20) }
  let(:new_password) { Faker::Alphanumeric.alpha(number: 20) }
  let(:email) { fake_user.email }

  it "complete password reset workflow" do
    ####
    # Create a new user
    post(:create_post, params: {
      first_name: fake_user.first_name,
      last_name: fake_user.last_name,
      username: fake_user.username,
      email: fake_user.email,
      password: password,
      password_confirmation: password,
    })
    expect(response.status).to eq(201)

    user = User.find_by(email: email)

    ####
    # Request password reset email
    post(:password_forgot_send_post, params: { email: email })
    expect(response.status).to eq(200)
    expect(JSON.parse(response.body)["message"]).to eq("If an account exists with that email, a password reset link has been sent.")

    ####
    # Verify email was sent
    expect(ActionMailer::Base.deliveries.count).to eq(1)

    ####
    # Get the reset token from user_secrets
    user_secret = UserSecret.where(user: user, reason: CommandTower::Secrets::PASSWORD_RESET).last
    expect(user_secret).to be_present
    token = user_secret.secret

    ####
    # Validate the token
    post(:password_forgot_validate_post, params: { token: token })
    expect(response.status).to eq(200)
    validate_response = JSON.parse(response.body)
    expect(validate_response["valid"]).to eq(true)
    expect(validate_response["expires_at"]).to be_present

    ####
    # Reset password with token
    post(:password_forgot_reset_post, params: {
      token: token,
      password: new_password,
      password_confirmation: new_password,
    })
    expect(response.status).to eq(200)
    expect(JSON.parse(response.body)["message"]).to eq("Password has been successfully reset")

    ####
    # Verify old password no longer works
    post(:login_post, params: {
      identifier: email,
      password: password,
    })
    expect(response.status).to eq(401)

    ####
    # Verify new password works
    post(:login_post, params: {
      identifier: email,
      password: new_password,
    })
    expect(response.status).to eq(201)
    login_response = JSON.parse(response.body)
    expect(login_response["token"]).to be_present

    ####
    # Verify token cannot be reused
    post(:password_forgot_reset_post, params: {
      token: token,
      password: "another_password123",
      password_confirmation: "another_password123",
    })
    expect(response.status).to eq(401)
    expect(JSON.parse(response.body)["message"]).to eq("Invalid token")
  end

  it "password reset with non-existent email returns 200" do
    ####
    # Request password reset for non-existent email
    post(:password_forgot_send_post, params: { email: "nonexistent@example.com" })
    expect(response.status).to eq(200)
    expect(JSON.parse(response.body)["message"]).to eq("If an account exists with that email, a password reset link has been sent.")

    ####
    # Verify no email was sent
    expect(ActionMailer::Base.deliveries.count).to eq(0)
  end

  it "password reset with invalid token returns 401" do
    ####
    # Try to validate invalid token
    post(:password_forgot_validate_post, params: { token: "invalid_token_12345" })
    expect(response.status).to eq(401)
    expect(JSON.parse(response.body)["message"]).to eq("Invalid token")

    ####
    # Try to reset password with invalid token
    post(:password_forgot_reset_post, params: {
      token: "invalid_token_12345",
      password: "new_password123",
      password_confirmation: "new_password123",
    })
    expect(response.status).to eq(401)
    expect(JSON.parse(response.body)["message"]).to eq("Invalid token")
  end

  it "password reset with expired token returns 401" do
    ####
    # Create a user
    post(:create_post, params: {
      first_name: fake_user.first_name,
      last_name: fake_user.last_name,
      username: fake_user.username,
      email: fake_user.email,
      password: password,
      password_confirmation: password,
    })
    user = User.find_by(email: email)

    ####
    # Generate an expired token
    result = CommandTower::Secrets::Generate.(
      user: user,
      secret_length: 32,
      reason: CommandTower::Secrets::PASSWORD_RESET,
      use_count_max: 1,
      death_time: 1.hour,
      type: CommandTower::Secrets::ALPHANUMERIC,
      cleanse: false
    )
    expired_token = result.secret
    # Manually expire the token by setting death_time in the past
    user_secret = UserSecret.find_by(secret: expired_token)
    user_secret.update!(death_time: 1.hour.ago)

    ####
    # Try to validate expired token
    post(:password_forgot_validate_post, params: { token: expired_token })
    expect(response.status).to eq(401)
    expect(JSON.parse(response.body)["message"]).to eq("Invalid token")

    ####
    # Try to reset password with expired token
    post(:password_forgot_reset_post, params: {
      token: expired_token,
      password: "new_password123",
      password_confirmation: "new_password123",
    })
    expect(response.status).to eq(401)
    expect(JSON.parse(response.body)["message"]).to eq("Invalid token")
  end
end
