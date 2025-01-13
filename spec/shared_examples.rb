# frozen_string_literal: true

RSpec.shared_examples "ApiEngineBase::Schema::Error:InvalidArguments examples" do |status, message, keys|
  context "with shared example -- InvalidArguments" do
    let(:response_body) { JSON.parse(response.body) }

    it "sets #{status} status" do
      subject

      expect(response.status).to eq(status)
    end

    it "sets message" do
      subject

      expect(response_body["message"]).to include(*Array(message))
    end

    it "sets invalid_arguments" do
      subject

      safe_keys = Array(keys).map(&:to_s)
      safe_keys.each do |k|
        expect(response_body["invalid_arguments"]).to include(
          hash_including(
          "schema" => be_a(String),
          "argument" => k,
          "reason" => be_a(String),
        ))
      end
    end

    it "sets invalid_argument_keys" do
      subject

      safe_keys = Array(keys).map(&:to_s)
      expect(response_body["invalid_argument_keys"]).to include(*safe_keys)
    end
  end
end

RSpec.shared_examples "Invalid/Missing JWT token on required route" do
  context "with shared example -- UnAuthenticated User(JWT token)" do
    let(:response_body) { JSON.parse(response.body) }

    context "with token missing" do
       before { unset_jwt_token! }

       it "sets 401 status" do
         subject
         expect(response.status).to eq(401)
       end

       it "sets invalid message" do
         subject
         expect(response_body["message"]).to eq("Bearer token missing")
       end
    end

    context "with valid token" do
      let(:user) { create(:user) }
      let!(:verifier_token) { user.retreive_verifier_token! }
      let(:payload) { { expires_at:, user_id: user.id, verifier_token: } }
      let(:token) { ApiEngineBase::Jwt::Encode.(payload:).token }
      let(:expires_at) { ApiEngineBase.config.jwt.ttl.from_now.to_i }
      before { set_jwt_token!(user:, token:) }

      context "when token is expired" do
        let(:expires_at) { (Time.now - 1.day).to_i }

        it "sets 401 status" do
          subject
          expect(response.status).to eq(401)
        end

        it "sets invalid message" do
          subject
          expect(response_body["message"]).to eq("Unauthorized Access. Invalid Authorization token")
        end
      end

      context "when token verifier does not match" do
        let(:verifier_token) { SecureRandom.alphanumeric(32) }

        it "sets 401 status" do
          subject
          expect(response.status).to eq(401)
        end

        it "sets invalid message" do
          subject
          expect(response_body["message"]).to eq("Unauthorized Access. Token is no longer valid")
        end
      end
    end
  end
end

RSpec.shared_examples "UnAuthorized Access on Controller Action" do
  context "with shared example -- UnAuthorized User" do
    it "sets 403 status" do
      subject
      expect(response.status).to eq(403)
    end

    it "sets invalid message" do
      subject
      expect(response_body["message"]).to eq("Unauthorized Access. Incorrect User Privileges")
    end
  end
end
