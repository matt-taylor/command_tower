# frozen_string_literal: true

RSpec.describe CommandTower::Services::HomeNotices::Compose do
  let(:user) { create(:user) }
  let(:helpers) { HomeNoticeSpecHelpers }
  let(:warnings) { [] }
  let(:notice) { helpers.terms_notice }
  let(:result) { helpers.compose(notice, user:) }

  around do |example|
    listener = lambda do |name, _start, _finish, _id, payload|
      warnings << "#{name} #{payload.to_h.slice(:notice_key, :error_class)}"
    end
    ActiveSupport::Notifications.subscribed(listener, /\Acommand_tower\.home_notices\./) { example.run }
  end

  it "builds a validated document with derived fallback text and a hash", :aggregate_failures do
    expect(result).to be_success
    expect(result.data[:document]).to be_a(CommandTower::UI::Document)
    expect(result.data[:document].text_fallback).to eq("Terms updated\nPlease review them.")
    expect(result.data[:content_hash]).to match(/\A\h{64}\z/)
  end

  it "gives a stable hash for the same content" do
    expect(helpers.compose(helpers.terms_notice, user:).data[:content_hash]).to eq(result.data[:content_hash])
  end

  it "gives a different hash for different content" do
    expect(helpers.compose(helpers.different_notice, user:).data[:content_hash])
      .not_to eq(result.data[:content_hash])
  end

  it "keys the hash rather than using a plain SHA-256 of the document" do
    expect(result.data[:content_hash]).not_to eq(Digest::SHA256.hexdigest(helpers.document_json(result)))
  end

  context "when the client catalog is below 2" do
    let(:result) { helpers.compose(notice, user:, ui_catalog: 1) }

    it "returns no document and no hash", :aggregate_failures do
      expect(result).to be_success
      expect(result.data[:document]).to be_nil
      expect(result.data[:content_hash]).to be_nil
    end
  end

  describe "redaction" do
    let(:notice) { helpers.code_notice }

    it "redacts code nodes when impersonating" do
      expect(helpers.document_json(helpers.compose(notice, user:, impersonating: true))).not_to include("SECRET123")
    end

    it "redacts code nodes when impersonation is unknown" do
      expect(helpers.document_json(helpers.compose(notice, user:, impersonating: "unknown")))
        .not_to include("SECRET123")
    end

    it "keeps code nodes when explicitly not impersonating" do
      expect(helpers.document_json(result)).to include("SECRET123")
    end
  end

  context "with a blocking notice that has an internal link" do
    let(:notice) { helpers.internal_link_notice }

    it "skips it and logs the key only", :aggregate_failures do
      expect(result.data[:document]).to be_nil
      expect(warnings.join("\n")).to include("command_tower.home_notices.blocking_invalid")
      expect(warnings.join("\n")).to include("test.terms")
      expect(warnings.join("\n")).not_to include("/settings")
    end
  end

  context "with a dismissible notice that has an internal link" do
    let(:notice) { helpers.internal_link_notice(kind: :dismissible) }

    it "uses the default profile" do
      expect(result.data[:document]).to be_a(CommandTower::UI::Document)
    end
  end

  context "when compose raises" do
    let(:notice) { helpers.raising_notice }

    it "skips the notice and logs the key and error class only", :aggregate_failures do
      expect(result.data[:document]).to be_nil
      expect(warnings.join("\n")).to include("test.terms")
      expect(warnings.join("\n")).to include("RuntimeError")
      expect(warnings.join("\n")).not_to include("secret")
    end
  end
end
