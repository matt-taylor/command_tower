# frozen_string_literal: true

RSpec.describe "Login body token omission", type: :request do
  let(:user) { create(:user, password: "password1234") }
  let(:body) { response.parsed_body }
  let(:cookie_enabled) { true }
  let(:omit_flag) { true }

  before do
    CommandTower.configure do |config|
      config.jwt.cookie.enabled = cookie_enabled
      config.session.omit_body_token = omit_flag
    end
  end

  context "when the request is the new web client in cookie mode" do
    let(:headers) { { "X-Client-Platform" => "web", "X-App-Version" => "0.4.0" } }

    it "omits token from the body" do
      post_plain_text_login(user, headers: headers)
      expect(body.dig("data", "token")).to be_nil
    end

    it "keeps tokenExpiresAt" do
      post_plain_text_login(user, headers: headers)
      expect(body.dig("data", "tokenExpiresAt")).to be_present
    end

    it "still sets the auth cookie" do
      post_plain_text_login(user, headers: headers)
      expect(Array(response.headers["Set-Cookie"]).join("\n")).to include(CommandTower.config.jwt.cookie.name)
    end

    it "omits for a later version" do
      post_plain_text_login(user, headers: headers.merge("X-App-Version" => "v1.2.0"))
      expect(body.dig("data", "token")).to be_nil
    end

    context "when the flag is off" do
      let(:omit_flag) { false }

      it "keeps token" do
        post_plain_text_login(user, headers: headers)
        expect(body.dig("data", "token")).to be_present
      end
    end

    context "when cookie auth is disabled" do
      let(:cookie_enabled) { false }

      it "keeps token" do
        post_plain_text_login(user, headers: headers)
        expect(body.dig("data", "token")).to be_present
      end
    end
  end

  context "when the client is not the new web client" do
    it "keeps token for an old web version" do
      post_plain_text_login(user, headers: { "X-Client-Platform" => "web", "X-App-Version" => "0.3.0" })
      expect(body.dig("data", "token")).to be_present
    end

    it "keeps token for native" do
      post_plain_text_login(user, headers: { "X-Client-Platform" => "ios", "X-App-Version" => "0.4.0" })
      expect(body.dig("data", "token")).to be_present
    end

    it "keeps token when the platform is missing" do
      post_plain_text_login(user, headers: { "X-App-Version" => "0.4.0" })
      expect(body.dig("data", "token")).to be_present
    end

    it "keeps token when the version is missing" do
      post_plain_text_login(user, headers: { "X-Client-Platform" => "web" })
      expect(body.dig("data", "token")).to be_present
    end

    it "keeps token when the version is malformed" do
      post_plain_text_login(user, headers: { "X-Client-Platform" => "web", "X-App-Version" => "abc" })
      expect(body.dig("data", "token")).to be_present
    end
  end
end
