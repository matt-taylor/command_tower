# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::NotificationTypes::Declaration, :messaging_notification_types do
  describe ".build" do
    context "when inbox_document_composer is not given" do
      subject(:declaration) { build_notification_type_declaration }

      it "defaults inbox_document_composer to nil" do
        expect(declaration.inbox_document_composer).to be_nil
      end
    end

    context "when inbox_document_composer is given a class-name String" do
      subject(:declaration) do
        build_notification_type_declaration(
          inbox_document_composer: "Services::Competitive::Messaging::InboxDocuments::IncompleteWager",
        )
      end

      it "stores the class-name String verbatim" do
        expect(declaration.inbox_document_composer).to eq(
          "Services::Competitive::Messaging::InboxDocuments::IncompleteWager",
        )
      end
    end

    context "when inbox_document_composer is given a non-String" do
      subject(:declaration) { build_notification_type_declaration(inbox_document_composer: :some_symbol) }

      it "coerces it to a String" do
        expect(declaration.inbox_document_composer).to eq("some_symbol")
      end
    end

    context "when the declaration is built" do
      subject(:declaration) { build_notification_type_declaration }

      it "is frozen" do
        expect(declaration).to be_frozen
      end
    end
  end
end
