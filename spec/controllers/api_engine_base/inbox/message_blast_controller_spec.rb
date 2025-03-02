# frozen_string_literal: true

RSpec.describe ApiEngineBase::Inbox::MessageBlastController, :with_rbac_setup, type: :controller do
  let(:response_body) { JSON.parse(response.body) }

  before { set_jwt_token!(user:) }
  let(:user) { create(:user, roles: ["admin"]) }

  describe "GET: metadata" do
    subject(:metadata) { get(:metadata) }

    it "returns 200" do
      metadata

      expect(response.status).to eq(200)
    end

    it "returns metadata values" do
      metadata
      expect(response_body).to include(*ApiEngineBase::Schema::Inbox::MessageBlastMetadata.introspect.keys)
    end

    context "with auth* failures" do
      let(:user) { create(:user) }

      include_examples "Invalid/Missing JWT token on required route"
      include_examples "UnAuthorized Access on Controller Action"
    end
  end

  describe "GET: blast" do
    subject(:blast) { get(:blast, params: { id: }) }

    let(:message_blast) { create(:message_blast) }
    let(:id) { message_blast.id }

    it "returns 200" do
      blast

      expect(response.status).to eq(200)
    end

    it "returns entity values" do
      blast

      expect(response_body).to include(*ApiEngineBase::Schema::Inbox::MessageBlastEntity.introspect.keys)
      expect(response_body["text"]).to eq(message_blast.text)
    end

    context "with invalid ID" do
      let(:id) { 1 }

      include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, "MessageBlast ID not found", :id
    end

    context "with auth* failures" do
      let(:user) { create(:user) }

      include_examples "Invalid/Missing JWT token on required route"
      include_examples "UnAuthorized Access on Controller Action"
    end
  end

  describe "POST: create" do
    subject(:create_post) { post(:create, params:) }

    let(:params) do
      {
        existing_users:,
        new_users:,
        text:,
        title:,
      }.compact
    end

    let(:existing_users) { false }
    let(:new_users) { true }
    let(:text) { "this is the text to send" }
    let(:title) { "this is the title" }

    it "returns 200" do
      create_post

      expect(response.status).to eq(200)
    end

    it do
      expect { create_post }.to change(::MessageBlast, :count).by(1)
    end

    it "returns blast" do
      create_post

      expect(response_body).to include(*ApiEngineBase::Schema::Inbox::BlastResponse.introspect.keys)
      expect(response_body["text"]).to eq(text)
    end

    context "with invalid params" do
      let(:title) { nil }

      include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, "Parameter [title] is required but not present", :title
    end

    context "with auth* failures" do
      let(:user) { create(:user) }

      include_examples "Invalid/Missing JWT token on required route"
      include_examples "UnAuthorized Access on Controller Action"
    end
  end

  describe "POST: modify" do
    subject(:modify) { post(:modify, params:) }

    let(:params) do
      {
        existing_users:,
        new_users:,
        text:,
        title:,
        id: message_blast.id,
      }.compact
    end
    let!(:message_blast) { create(:message_blast) }
    let(:existing_users) { message_blast.existing_users }
    let(:new_users) { message_blast.new_users }
    let(:text) { "this is the new text to set to" }
    let(:title) { message_blast.title }

    it "returns 200" do
      modify

      expect(response.status).to eq(200)
    end

    it do
      expect { modify }.to_not change(::MessageBlast, :count)
    end

    it "returns blast" do
      modify

      expect(response_body).to include(*ApiEngineBase::Schema::Inbox::BlastResponse.introspect.keys)
    end

    it "modifies existing blast" do
      expect { modify }.to change { message_blast.reload.text }.to(text)
    end

    context "with invalid params" do
      let(:title) { nil }

      include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, "Parameter [title] is required but not present", :title
    end

    context "with auth* failures" do
      let(:user) { create(:user) }

      include_examples "Invalid/Missing JWT token on required route"
      include_examples "UnAuthorized Access on Controller Action"
    end
  end

  describe "DELETE: delete" do
    subject(:del) { delete(:delete, params: { id: }) }

    let(:id) { message_blast.id }
    let!(:message_blast) { create(:message_blast) }

    it "returns 200" do
      del

      expect(response.status).to eq(200)
    end

    it "deletes blast" do
      expect { del }.to change(MessageBlast, :count).by(-1)
    end

    context "with invalid id" do
      let(:id) { 1234 }

      include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, "MessageBlast ID not found", :id
    end
  end
end

