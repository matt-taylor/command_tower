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

    context "when no NPB fields are given" do
      let(:permitted_choice) { CommandTower::Messaging::NotificationTypes::PermittedChoice }

      subject(:declaration) { build_notification_type_declaration }

      it "defaults to today's behavior" do
        expect(declaration.badge_eligible).to be(false)
        expect(declaration.deep_link_required).to be(false)
        expect(declaration.urgency).to eq(permitted_choice.new(default: "normal", allowed: %w[normal]))
        expect(declaration.sound).to eq(permitted_choice.new(default: "default", allowed: %w[default]))
      end

      it "is fixed for urgency and sound" do
        expect([declaration.urgency.mode, declaration.sound.mode]).to eq(%i[fixed fixed])
      end

      it "leaves priority unchanged" do
        expect(declaration.priority).to be_nil
      end
    end

    context "when badge_eligible is truthy" do
      subject(:declaration) { build_notification_type_declaration(badge_eligible: true) }

      it "stores true" do
        expect(declaration.badge_eligible).to be(true)
      end
    end

    context "when urgency is restricted with symbol keys" do
      subject(:declaration) do
        build_notification_type_declaration(
          urgency: { default: :normal, allowed: %i[normal time_sensitive] },
        )
      end

      it "normalizes to strings and derives restricted mode" do
        expect(declaration.urgency.default).to eq("normal")
        expect(declaration.urgency.allowed).to eq(%w[normal time_sensitive])
        expect(declaration.urgency.mode).to eq(:restricted)
      end

      it "freezes the permitted list" do
        expect(declaration.urgency.allowed).to be_frozen
      end
    end

    context "when sound allows the full catalog" do
      subject(:declaration) { build_notification_type_declaration(sound: { default: "default", allowed: "all" }) }

      it "derives full mode" do
        expect(declaration.sound.mode).to eq(:full)
      end
    end

    context "when sound omits allowed" do
      subject(:declaration) { build_notification_type_declaration(sound: { default: "chime" }) }

      it "is fixed on the default" do
        expect(declaration.sound.allowed).to eq(%w[chime])
      end
    end

    context "when urgency is not a hash" do
      subject(:declaration) { build_notification_type_declaration(urgency: "normal") }

      it "keeps the value for the validator to report" do
        expect(declaration.urgency).to eq("normal")
      end
    end
  end
end
