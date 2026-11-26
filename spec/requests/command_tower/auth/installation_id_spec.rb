# frozen_string_literal: true

RSpec.describe "Installation id at the boundary", type: :request do
  let(:uuid_v4) { /\h{8}-\h{4}-4\h{3}-[89ab]\h{3}-\h{12}/i }
  let(:user) { create(:user, password: "password1234") }
  let(:installation_id) { SecureRandom.uuid }
  let(:set_cookie) { Array(response.headers["Set-Cookie"]).join("\n") }
  let(:stored_id) { CommandTower::Auth::DeviceSession.where(user_id: user.id).order(:id).last.installation_id }

  context "when cookie auth is enabled" do
    before { CommandTower.configure { |config| config.jwt.cookie.enabled = true } }

    it "plants a UUID v4 ct_installation cookie on a web login with no id" do
      post_plain_text_login(user)
      expect(set_cookie).to match(/ct_installation=#{uuid_v4.source}/i)
    end

    it "plants the cookie HttpOnly" do
      post_plain_text_login(user)
      expect(set_cookie).to match(/ct_installation=[^\n]*httponly/i)
    end

    it "stores the planted id on the device session" do
      post_plain_text_login(user)
      expect(stored_id).to eq(set_cookie[/ct_installation=([^;\n]+)/, 1])
    end

    it "reads the id from the cookie" do
      cookies["ct_installation"] = installation_id
      post_plain_text_login(user)
      expect(stored_id).to eq(installation_id)
    end

    it "keeps the cookie value when it was read from the cookie" do
      cookies["ct_installation"] = installation_id
      post_plain_text_login(user)
      expect(set_cookie).to include("ct_installation=#{installation_id}")
    end

    it "does not plant the cookie when the header carries the id" do
      post_plain_text_login(user, headers: { "X-Installation-Id" => installation_id })
      expect(set_cookie).not_to include("ct_installation")
    end

    it "stores the header id" do
      post_plain_text_login(user, headers: { "X-Installation-Id" => installation_id })
      expect(stored_id).to eq(installation_id)
    end

    it "prefers the header over the cookie" do
      cookies["ct_installation"] = SecureRandom.uuid
      post_plain_text_login(user, headers: { "X-Installation-Id" => installation_id })
      expect(stored_id).to eq(installation_id)
    end

    it "ignores a header that is not a UUID" do
      post_plain_text_login(user, headers: { "X-Installation-Id" => "not-a-uuid" })
      expect(stored_id).to match(uuid_v4)
    end

    context "with a version 1 UUID" do
      let(:installation_id) { "6ba7b810-9dad-11d1-80b4-00c04fd430c8" }

      it "ignores a UUID that is not version 4" do
        post_plain_text_login(user, headers: { "X-Installation-Id" => installation_id })
        expect(stored_id).not_to eq(installation_id)
      end
    end

    it "replaces the earlier session of the same installation" do
      2.times { post_plain_text_login(user, headers: { "X-Installation-Id" => installation_id }) }
      expect(CommandTower::Auth::DeviceSession.active.where(user_id: user.id).count).to eq(1)
    end
  end

  context "when cookie auth is disabled" do
    before { CommandTower.configure { |config| config.jwt.cookie.enabled = false } }

    it "stores the header id" do
      post_plain_text_login(user, headers: { "X-Installation-Id" => installation_id })
      expect(stored_id).to eq(installation_id)
    end

    it "plants no cookie" do
      post_plain_text_login(user, headers: { "X-Installation-Id" => installation_id })
      expect(set_cookie).not_to include("ct_installation")
    end

    it "stores no id when none is sent" do
      post_plain_text_login(user)
      expect(stored_id).to be_nil
    end
  end
end
