# frozen_string_literal: true

RSpec.describe "FoundationProof::Echo", type: :request do
  describe "POST /foundation_proof/echo" do
    subject(:perform_request) { post "/foundation_proof/echo", params: params, as: :json }

    context "with valid params" do
      let(:params) { { message: "hello", limit: 5 } }

      it "returns the success envelope" do
        perform_request

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["data"]).to eq("message" => "hello", "limit" => 5)
        expect(body["meta"]).to eq("source" => "foundation_proof")
        expect(body["errors"]).to eq([])
      end

      it "applies set_expire_header" do
        perform_request

        expect(response.headers[CommandTower::Jwt::AuthorizationHelper::AUTHENTICATION_EXPIRE_HEADER])
          .to eq(FoundationProof::EchoWorkflow::EXPIRE_HEADER_VALUE)
      end
    end

    context "when message is missing" do
      let(:params) { { limit: 5 } }

      it "returns a validation failure envelope" do
        perform_request

        expect(response).to have_http_status(:unprocessable_entity)
        error = response.parsed_body["errors"].first
        expect(error["code"]).to eq("validation_failed")
        expect(error["details"]["failures"]).to include(
          hash_including("code" => "missing_required_fields", "field" => "message")
        )
      end
    end

    context "when limit is invalid" do
      let(:params) { { message: "hello", limit: 999 } }

      it "returns a typed deserializer failure" do
        perform_request

        expect(response).to have_http_status(:unprocessable_entity)
        failures = response.parsed_body["errors"].first["details"]["failures"]
        expect(failures).to include(hash_including("code" => "invalid_limit", "field" => "limit"))
      end
    end
  end
end
