# frozen_string_literal: true

# Journey coverage through the service layer (register → send → validate → reset → login).
# HTTP contracts: spec/requests/command_tower/auth/password_reset_*_spec.rb
# Edge cases (unknown email, invalid/expired token): service + request unit specs.
RSpec.describe "Plain text password reset journey" do
  let(:fake_user) { build(:user, password:) }
  let(:password) { Faker::Alphanumeric.alpha(number: 20) }
  let(:new_password) { Faker::Alphanumeric.alpha(number: 20) }
  let(:email) { fake_user.email }
  let(:non_enumerating_message) { CommandTower::Services::Auth::PasswordReset::Send::SENT_MESSAGE }

  def register!
    result = CommandTower::Services::Auth::Register.call(
      first_name: fake_user.first_name,
      last_name: fake_user.last_name,
      username: fake_user.username,
      email: fake_user.email,
      password: password,
      password_confirmation: password
    )
    expect(result).to be_success

    result.data[:user]
  end

  it "complete password reset workflow" do
    user = register!

    ####
    # Request password reset email
    send_result = CommandTower::Services::Auth::PasswordReset::Send.call(email:)
    expect(send_result).to be_success
    expect(send_result.data[:message]).to eq(non_enumerating_message)

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
    validate_result = CommandTower::Services::Auth::PasswordReset::Validate.call(token:)
    expect(validate_result).to be_success
    expect(validate_result.data[:valid]).to eq(true)
    expect(validate_result.data[:expires_at]).to be_present

    ####
    # Reset password with token
    reset_result = CommandTower::Services::Auth::PasswordReset::Reset.call(
      token:,
      password: new_password,
      password_confirmation: new_password
    )
    expect(reset_result).to be_success
    expect(reset_result.data[:message]).to eq(CommandTower::Services::Auth::PasswordReset::Reset::RESET_MESSAGE)

    ####
    # Verify old password no longer works
    old_login = CommandTower::Services::Auth::PlainText::Login.call(identifier: email, password: password)
    expect(old_login).to be_failure

    ####
    # Verify new password works
    new_login = CommandTower::Services::Auth::PlainText::Login.call(identifier: email, password: new_password)
    expect(new_login).to be_success
    expect(new_login.data[:token]).to be_present

    ####
    # Verify token cannot be reused
    reuse_result = CommandTower::Services::Auth::PasswordReset::Reset.call(
      token:,
      password: "another_password123",
      password_confirmation: "another_password123"
    )
    expect(reuse_result).to be_failure
    expect(reuse_result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordResetInvalidTokenError)
  end
end
