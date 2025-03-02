# frozen_string_literal: true

RSpec.describe ApiEngineBase::Inbox::MessageController, type: :controller do
  let(:response_body) { JSON.parse(response.body) }
  let(:user) { create(:user) }
  let!(:messages) { create_list(:message, 5, user:) }
  let(:ids) { messages.pluck(:id) }

  before { set_jwt_token!(user:) }

  describe "GET: metadata" do
    subject(:metadata) { get(:metadata) }

    it "returns 200" do
      metadata

      expect(response.status).to eq(200)
    end

    it "returns metadata values" do
      metadata
      expect(response_body).to include(*ApiEngineBase::Schema::Inbox::Metadata.introspect.keys)
    end

    include_examples "Invalid/Missing JWT token on required route"
  end

  describe "GET: message" do
    subject(:message) { get(:message, params: { id: }) }

    let(:id) { record.id }
    let(:record) { messages.sample }

    it "returns 200" do
      message

      expect(response.status).to eq(200)
    end

    it "returns message values" do
      message

      expect(response_body).to include(*ApiEngineBase::Schema::Inbox::MessageEntity.introspect.keys)
      expect(response_body["text"]).to eq(record.text)
    end

    context "with incorrect ID" do
      let(:id) { 1233456 }

      include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, "Message ID not found for user", :id
    end

    include_examples "Invalid/Missing JWT token on required route"
  end

  shared_examples "modify message metadata" do |modify_type|
    it "returns 200" do
      subject

      expect(response.status).to eq(200)
    end

    it "changes metadata" do
      subject

      expect(response_body).to include(*ApiEngineBase::Schema::Inbox::Modified.introspect.keys)
      expect(response_body["count"]).to eq(messages.length)
      expect(response_body["type"]).to eq(modify_type)
      expect(response_body["ids"]).to include(*ids)
    end

    context "with unknown ids" do
      let(:ids) { [1234567, 7654321] }

      include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, "No ID's found for user", :ids
    end

    context "when id included that does not belong" do
      let(:ids) { available_ids + unknown_ids }
      let(:available_ids) { messages.pluck(:id) }
      let(:unknown_ids) { [1234567, 7654321] }

      it "returns 200" do
        subject

        expect(response.status).to eq(200)
      end

      it "changes metadata" do
        subject

        expect(response_body).to include(*ApiEngineBase::Schema::Inbox::Modified.introspect.keys)
        expect(response_body["count"]).to eq(messages.length)
        expect(response_body["type"]).to eq(modify_type)
        expect(response_body["ids"]).to include(*available_ids)
        expect(response_body["ids"]).to_not include(*unknown_ids)
      end
    end
  end

  describe "POST: ack" do
    subject(:ack) { post(:ack, params: { ids: }) }

    include_examples "modify message metadata", "viewed"
    include_examples "Invalid/Missing JWT token on required route"
  end

  describe "POST: delete" do
    subject(:delete) { post(:delete, params: { ids: }) }

    include_examples "modify message metadata", "delete"
    include_examples "Invalid/Missing JWT token on required route"
  end
end
