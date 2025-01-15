RSpec.describe ApiEngineBase::AdminController, type: :controller do
  let(:user) { create(:user, :role_admin) }


  it "sends regenerated token" do
    set_jwt_token!(user:)
    get(:show)
    generated_token = response.headers[ApiEngineBase::ApplicationController::AUTHENTICATION_WITH_RESET.downcase]
    expect(generated_token).to be_nil


    set_jwt_token!(user:, with_reset: true)
    get(:show)

    generated_token = response.headers[ApiEngineBase::ApplicationController::AUTHENTICATION_WITH_RESET.downcase]
    expect(generated_token).to be_a(String)

    result = ApiEngineBase::Jwt::AuthenticateUser.(token:generated_token)
    expect(result.success?).to be(true)
  end
end
