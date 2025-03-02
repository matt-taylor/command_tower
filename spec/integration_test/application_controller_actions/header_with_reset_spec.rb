RSpec.describe CommandTower::AdminController, type: :controller do
  let(:user) { create(:user, :role_admin) }


  it "sends regenerated token" do
    ###
    # Get Show without the Reset token and verify it does not show up
    set_jwt_token!(user:)
    get(:show)
    generated_token = response.headers[CommandTower::ApplicationController::AUTHENTICATION_WITH_RESET.downcase]
    expect(generated_token).to be_nil

    ###
    # Get Show WITH the Reset token and verify it shows up
    set_jwt_token!(user:, with_reset: true)
    get(:show)
    generated_token = response.headers[CommandTower::ApplicationController::AUTHENTICATION_WITH_RESET.downcase]
    expect(generated_token).to be_a(String)

    ###
    # Verify the token is valid
    result = CommandTower::Jwt::AuthenticateUser.(token:generated_token)
    expect(result.success?).to be(true)

    ###
    # Verify the token can be used
    set_jwt_token!(user:, token: result.token)
    get(:show)
  end
end
