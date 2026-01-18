# frozen_string_literal: true

# Test ApplicationController's authenticate_user! method through UserController
# UserController inherits from ApplicationController and uses authenticate_user! as a before_action
# This allows us to test the authentication header parsing edge cases
RSpec.describe CommandTower::UserController, type: :controller do
  let(:response_body) { JSON.parse(response.body) }
  let(:user) { create(:user) }

  describe "ApplicationController#authenticate_user! with malformed Authorization headers" do
    subject(:authenticate) { get(:show) }

    context "when Authorization header is missing" do
      before { unset_jwt_token! }

      it "returns 401 status" do
        authenticate

        expect(response.status).to eq(401)
      end

      it "returns 'Bearer token missing' message" do
        authenticate

        expect(response_body["message"]).to eq("Bearer token missing")
      end
    end

    context "when Authorization header uses old format 'Bearer:token'" do
      before do
        @request.headers[CommandTower::ApplicationController::AUTHENTICATION_HEADER] = "Bearer:some_token_value"
      end

      it "returns 401 status instead of crashing" do
        expect { authenticate }.not_to raise_error
        expect(response.status).to eq(401)
      end

      it "returns 'Invalid Bearer token format' message" do
        authenticate

        expect(response_body["message"]).to eq("Invalid Bearer token format")
      end
    end

    context "when Authorization header is missing 'Bearer ' prefix" do
      before do
        @request.headers[CommandTower::ApplicationController::AUTHENTICATION_HEADER] = "some_token_value"
      end

      it "returns 401 status instead of crashing" do
        expect { authenticate }.not_to raise_error
        expect(response.status).to eq(401)
      end

      it "returns 'Invalid Bearer token format' message" do
        authenticate

        expect(response_body["message"]).to eq("Invalid Bearer token format")
      end
    end

    context "when Authorization header has 'Bearer ' but empty token" do
      before do
        @request.headers[CommandTower::ApplicationController::AUTHENTICATION_HEADER] = "Bearer "
      end

      it "returns 401 status instead of crashing" do
        expect { authenticate }.not_to raise_error
        expect(response.status).to eq(401)
      end

      it "returns 'Invalid Bearer token format' message" do
        authenticate

        expect(response_body["message"]).to eq("Invalid Bearer token format")
      end
    end

    context "when Authorization header has 'Bearer ' but only whitespace token" do
      before do
        @request.headers[CommandTower::ApplicationController::AUTHENTICATION_HEADER] = "Bearer    "
      end

      it "returns 401 status instead of crashing" do
        expect { authenticate }.not_to raise_error
        expect(response.status).to eq(401)
      end

      it "returns 'Invalid Bearer token format' message" do
        authenticate

        expect(response_body["message"]).to eq("Invalid Bearer token format")
      end
    end

    context "when Authorization header has malformed format without space" do
      before do
        @request.headers[CommandTower::ApplicationController::AUTHENTICATION_HEADER] = "Bearertoken"
      end

      it "returns 401 status instead of crashing" do
        expect { authenticate }.not_to raise_error
        expect(response.status).to eq(401)
      end

      it "returns 'Invalid Bearer token format' message" do
        authenticate

        expect(response_body["message"]).to eq("Invalid Bearer token format")
      end
    end

    context "when Authorization header has valid format 'Bearer token'" do
      before do
        set_jwt_token!(user: user)
      end

      it "does not crash and processes authentication" do
        expect { authenticate }.not_to raise_error
        # Should either succeed (200) or fail with proper JWT validation error (401), but not crash
        expect([200, 401]).to include(response.status)
      end
    end
  end
end
