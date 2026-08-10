# frozen_string_literal: true

RSpec.describe "GET /auth/identity-policy", type: :request do
  subject(:make_request) { get path }

  let(:path) { "/auth/identity-policy" }
  let(:plain_text) { CommandTower.config.login.plain_text }
  let(:username) { CommandTower.config.username }
  let(:email_verify) { plain_text.email_verify }

  before { make_request }

  it { expect(response).to have_http_status(:ok) }

  it "returns the identity policy in the envelope" do
    expect(response.parsed_body["data"]).to include(
      "password" => {
        "minLength" => plain_text.password_length_min + 1,
        "maxLength" => plain_text.password_length_max - 1
      },
      "email" => {
        "minLength" => plain_text.email_length_min + 1,
        "maxLength" => plain_text.email_length_max - 1
      },
      "username" => {
        "minLength" => username.username_length_min,
        "maxLength" => username.username_length_max,
        "pattern" => "^\\w{#{username.username_length_min},#{username.username_length_max}}$",
        "patternDescription" => username.username_failure_message
      },
      "verificationCode" => {
        "length" => email_verify.verify_code_length,
        "characterSet" => "numeric"
      },
      "phoneVerificationCode" => {
        "length" => CommandTower.config.identity.phone_verification.verify_code_length,
        "characterSet" => "numeric"
      }
    )
  end

  it "does not require a signup session" do
    expect(response).not_to have_http_status(:unauthorized)
  end
end
