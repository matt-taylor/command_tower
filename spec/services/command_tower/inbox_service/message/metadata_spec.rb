# frozen_string_literal: true

RSpec.describe CommandTower::InboxService::Message::Metadata do
  let(:user) { create(:user) }

  describe ".call" do
    subject(:call) { described_class.(user:, pagination:) }

    let(:pagination) { nil }

    it "succeeds" do
      expect(call.success?).to eq(true)
    end

    it "sets empty metadata" do
      expect(call.metadata).to be_a(CommandTower::Schema::Shared::Inbox::Metadata)
      expect(call.metadata.count).to eq(0)
      expect(call.metadata.entities).to eq([])
    end

    context "with messages" do
      before { create_list(:message, count, user:) }
      let(:count) { 1 }

      it "succeeds" do
        expect(call.success?).to eq(true)
      end

      it "sets metadata" do
        expect(call.metadata).to be_a(CommandTower::Schema::Shared::Inbox::Metadata)
        expect(call.metadata.count).to eq(count)
      end

      it "includes created_at in entities" do
        entities = call.metadata.entities
        expect(entities.length).to eq(count)
        entities.each do |entity|
          expect(entity.created_at).to be_present
          expect(entity.created_at).to be_a(String)
          # Verify it's a valid ISO 8601 date string
          expect { Time.iso8601(entity.created_at) }.not_to raise_error
        end
      end

      context "with many" do
        let(:count) { 10 }

        it "succeeds" do
          expect(call.success?).to eq(true)
        end

        it "sets metadata" do
          expect(call.metadata).to be_a(CommandTower::Schema::Shared::Inbox::Metadata)
          expect(call.metadata.count).to eq(count)
        end
      end
    end

    context "with include_examples" do
      let!(:records) { create_list(:message, count, user:) }
      let(:records_chain) { [:metadata, :entities] }
      let(:records_count) { [:metadata, :count] }

      include_examples "Services Pagination examples", ::Message
    end

    context "with pagination next field" do
      let(:pagination) { { limit:, page:, cursor: } }
      let(:limit) { 10 }
      let(:page) { nil }
      let(:cursor) { nil }

      context "when no records exist" do
        let(:count) { 0 }

        it "succeeds" do
          expect(call.success?).to eq(true)
        end

        it "sets pagination.next to nil" do
          expect(call.metadata.pagination).to be_present
          expect(call.metadata.pagination.next).to be_a(JsonSchematize::EmptyValue)
        end
      end

      context "when records exist" do
        before { create_list(:message, total_count, user:) }
        let(:total_count) { 25 }

        context "when on first page with more pages available" do
          let(:page) { 1 }
          let(:limit) { 10 }

          it "succeeds" do
            expect(call.success?).to eq(true)
          end

          it "sets pagination.next to present" do
            expect(call.metadata.pagination).to be_present
            expect(call.metadata.pagination.next).to be_present
            expect(call.metadata.pagination.next).to be_a(CommandTower::Schema::Shared::Page)
          end

          it "sets remaining_pages correctly" do
            expect(call.metadata.pagination.remaining_pages).to be > 0
          end
        end

        context "when on last page" do
          let(:page) { 3 }
          let(:limit) { 10 }

          it "succeeds" do
            expect(call.success?).to eq(true)
          end

          it "sets pagination.next to nil" do
            expect(call.metadata.pagination).to be_present
            expect(call.metadata.pagination.next).to be_a(JsonSchematize::EmptyValue)
          end

          it "sets remaining_pages to 0" do
            expect(call.metadata.pagination.remaining_pages).to eq(0)
          end
        end

        context "when cursor is exactly at limit" do
          let(:cursor) { 20 }
          let(:limit) { 5 }

          it "succeeds" do
            expect(call.success?).to eq(true)
          end

          it "sets pagination.next to nil" do
            expect(call.metadata.pagination).to be_present
            expect(call.metadata.pagination.next).to be_a(JsonSchematize::EmptyValue)
          end
        end

        context "when cursor exceeds total count" do
          let(:cursor) { 30 }
          let(:limit) { 10 }

          it "succeeds" do
            expect(call.success?).to eq(true)
          end

          it "sets pagination.next to nil" do
            expect(call.metadata.pagination).to be_present
            expect(call.metadata.pagination.next).to be_a(JsonSchematize::EmptyValue)
          end

          it "sets remaining_pages to 0" do
            expect(call.metadata.pagination.remaining_pages).to eq(0)
          end
        end

        context "when cursor is within bounds with more pages" do
          let(:cursor) { 10 }
          let(:limit) { 5 }

          it "succeeds" do
            expect(call.success?).to eq(true)
          end

          it "sets pagination.next to present" do
            expect(call.metadata.pagination).to be_present
            expect(call.metadata.pagination.next).to be_present
            expect(call.metadata.pagination.next).to be_a(CommandTower::Schema::Shared::Page)
          end

          it "sets remaining_pages correctly" do
            expect(call.metadata.pagination.remaining_pages).to be > 0
          end
        end

        context "when exactly one page of records" do
          let(:total_count) { 10 }
          let(:page) { 1 }
          let(:limit) { 10 }

          it "succeeds" do
            expect(call.success?).to eq(true)
          end

          it "sets pagination.next to nil" do
            expect(call.metadata.pagination).to be_present
            expect(call.metadata.pagination.next).to be_a(JsonSchematize::EmptyValue)
          end

          it "sets remaining_pages to 0" do
            expect(call.metadata.pagination.remaining_pages).to eq(0)
          end
        end
      end
    end
  end
end
