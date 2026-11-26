# frozen_string_literal: true

RSpec.describe "GET /auth/identity-policy", type: :request do
  subject(:make_request) { get path }

  let(:path) { "/auth/identity-policy" }
  let(:plain_text) { CommandTower.config.login.plain_text }
  let(:username) { CommandTower.config.username }
  let(:email_verify) { plain_text.email_verify }
  let(:data) { response.parsed_body["data"] }

  before { make_request }

  it { expect(response).to have_http_status(:ok) }

  it "returns the password policy in the envelope" do
    expect(data["password"]).to include(
      "minLength" => plain_text.password_length_min,
      "maxLength" => plain_text.password_length_max,
      "maxBytes" => 72
    )
  end

  it "returns the password rules in order" do
    expect(data["password"]["rules"].pluck("id")).to eq(%w[min_length max_length not_common not_identifier])
  end

  it "returns the email policy in the envelope" do
    expect(data["email"]).to include(
      "minLength" => plain_text.email_length_min,
      "maxLength" => plain_text.email_length_max
    )
  end

  it "returns the username policy in the envelope" do
    expect(data["username"]).to include(
      "minLength" => username.username_length_min,
      "maxLength" => username.username_length_max,
      "pattern" => "^\\w{#{username.username_length_min},#{username.username_length_max}}$",
      "patternDescription" => username.username_failure_message,
      "selfService" => false,
      "selfChange" => false,
      "prompt" => "after_signup"
    )
  end

  it "returns the verification code policies" do
    expect(data).to include(
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
