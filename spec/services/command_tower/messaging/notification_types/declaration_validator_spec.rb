# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::NotificationTypes::DeclarationValidator,
               :messaging_notification_types do
  describe ".validate" do
    subject(:errors) { described_class.validate(declaration) }

    let(:declaration) { build_notification_type_declaration }

    context "when the declaration is valid" do
      it "returns no errors" do
        expect(errors).to be_empty
      end
    end

    context "when the key is blank" do
      let(:declaration) { build_notification_type_declaration(key: "  ") }

      it "rejects a blank key" do
        expect(errors).to include("key must be present")
      end
    end

    context "when the key violates the identifier format" do
      let(:declaration) { build_notification_type_declaration(key: "Booking") }

      it "rejects keys that violate the established identifier format" do
        expect(errors).to include(
          "key must match the established notification identifier format",
        )
      end
    end

    context "when the label is blank" do
      let(:declaration) { build_notification_type_declaration(label: "  ") }

      it "rejects a blank label" do
        expect(errors).to include("label must be present")
      end
    end

    context "when the category_key is blank" do
      let(:declaration) { build_notification_type_declaration(category_key: "") }

      it "rejects a blank category_key" do
        expect(errors).to include("category_key must be present")
      end
    end

    context "when the category_key violates the identifier format" do
      let(:declaration) { build_notification_type_declaration(category_key: "Hello World") }

      it "rejects category_keys that violate the established identifier format" do
        expect(errors).to include(
          "category_key must match the established notification identifier format",
        )
      end
    end

    context "when the category_label is blank" do
      let(:declaration) { build_notification_type_declaration(category_label: nil) }

      it "rejects a blank category_label" do
        expect(errors).to include("category_label must be present")
      end
    end

    context "when category_order is not an Integer" do
      let(:declaration) { build_notification_type_declaration(category_order: "10") }

      it "rejects non-Integer category_order values" do
        expect(errors).to include(
          "category_order must be a non-negative Integer",
        )
      end
    end

    context "when type_order is negative" do
      let(:declaration) { build_notification_type_declaration(type_order: -1) }

      it "rejects negative type_order values" do
        expect(errors).to include(
          "type_order must be a non-negative Integer",
        )
      end
    end

    context "when type_order is a Float" do
      let(:declaration) { build_notification_type_declaration(type_order: 1.5) }

      it "rejects Float type_order values" do
        expect(errors).to include(
          "type_order must be a non-negative Integer",
        )
      end
    end

    context "when default channels are outside the allowed set" do
      let(:declaration) do
        build_notification_type_declaration(
          allowed_channels: %w[email],
          default_channels: %w[email sms],
        )
      end

      it "rejects default channels outside the allowed set" do
        expect(errors).to include(
          a_string_matching(/default_channels must be a subset/),
        )
      end
    end

    context "when channel lists are empty" do
      let(:declaration) do
        build_notification_type_declaration(
          allowed_channels: [],
          default_channels: [],
          default_preference_state: { "channels" => {}, "inbox" => true },
        )
      end

      it "accepts empty channel lists" do
        expect(errors).to be_empty
      end
    end

    context "when external channel keys are valid" do
      let(:declaration) do
        build_notification_type_declaration(
          allowed_channels: %w[email sms push],
          default_channels: %w[email sms],
        )
      end

      it "accepts valid external channel keys" do
        expect(errors).to be_empty
      end
    end

    context "when allowed_channels contains an unknown channel" do
      let(:declaration) { build_notification_type_declaration(allowed_channels: %w[fax]) }

      it "rejects unknown channels in allowed_channels" do
        expect(errors).to include(
          'allowed_channels contains unknown channel: "fax"',
        )
      end
    end

    context "when default_channels contains an unknown channel" do
      let(:declaration) do
        build_notification_type_declaration(
          allowed_channels: %w[email fax],
          default_channels: %w[fax],
        )
      end

      it "rejects unknown channels in default_channels" do
        expect(errors).to include(
          'default_channels contains unknown channel: "fax"',
        )
      end
    end

    context "when inbox appears in allowed_channels" do
      let(:declaration) { build_notification_type_declaration(allowed_channels: %w[inbox email]) }

      it "rejects inbox in allowed_channels" do
        expect(errors).to include(
          'allowed_channels contains non-external channel: "inbox"',
        )
      end
    end

    context "when inbox appears in default_channels" do
      let(:declaration) do
        build_notification_type_declaration(
          allowed_channels: %w[email inbox],
          default_channels: %w[inbox],
        )
      end

      it "rejects inbox in default_channels" do
        expect(errors).to include(
          'default_channels contains non-external channel: "inbox"',
        )
      end
    end

    context "when channel casing is mistyped" do
      let(:declaration) { build_notification_type_declaration(allowed_channels: %w[Email]) }

      it "rejects mistyped channel casing without downcasing" do
        expect(errors).to include(
          'allowed_channels contains unknown channel: "Email"',
        )
      end
    end

    context "when default_preference_state is missing" do
      let(:declaration) do
        CommandTower::Messaging::NotificationTypes::Declaration.new(
          key: "example.type",
          allowed_channels: %w[email].freeze,
          default_channels: %w[email].freeze,
          inbox_available: true,
          user_configurable: true,
          mandatory: false,
          default_preference_state: nil,
          label: "Example Type",
          category_key: "example",
          category_label: "Example",
          category_order: 10,
          type_order: 10,
          settings_visible: true,
          description: nil,
          priority: nil,
          retention: nil,
          delivery_status_visible: nil,
          host_ownership: nil,
        )
      end

      it "rejects a missing default preference state" do
        expect(errors).to include("default_preference_state is required")
      end
    end

    context "when settings_visible is not a boolean" do
      let(:declaration) do
        CommandTower::Messaging::NotificationTypes::Declaration.new(
          key: "example.type",
          allowed_channels: %w[email].freeze,
          default_channels: %w[email].freeze,
          inbox_available: true,
          user_configurable: true,
          mandatory: false,
          default_preference_state: {
            "channels" => { "email" => true },
            "inbox" => true,
          }.freeze,
          label: "Example Type",
          category_key: "example",
          category_label: "Example",
          category_order: 10,
          type_order: 10,
          settings_visible: nil,
          description: nil,
          priority: nil,
          retention: nil,
          delivery_status_visible: nil,
          host_ownership: nil,
        )
      end

      it "rejects a non-boolean settings_visible" do
        expect(errors).to include("settings_visible must be a boolean")
      end
    end
  end

  describe ".validate!" do
    context "when the declaration is invalid" do
      let(:declaration) { build_notification_type_declaration(key: "") }

      subject(:invoke) { described_class.validate!(declaration) }

      it "raises InvalidDeclarationError" do
        expect { invoke }.to raise_error(CommandTower::Messaging::NotificationTypes::InvalidDeclarationError)
      end
    end
  end

  describe ".validate_category_consistency!" do
    context "when category metadata matches across peers" do
      let(:first) { build_notification_type_declaration(key: "a.type", type_order: 10) }
      let(:second) { build_notification_type_declaration(key: "b.type", type_order: 20) }

      subject(:invoke) { described_class.validate_category_consistency!(second, peers: [first]) }

      it "allows matching category metadata across peers" do
        expect { invoke }.not_to raise_error
      end
    end

    context "when category_label conflicts for the same category_key" do
      let(:first) { build_notification_type_declaration(key: "a.type") }
      let(:second) do
        build_notification_type_declaration(
          key: "b.type",
          category_label: "Other",
        )
      end

      subject(:invoke) { described_class.validate_category_consistency!(second, peers: [first]) }

      it "rejects conflicting category_label for the same category_key" do
        expect { invoke }.to raise_error(
          CommandTower::Messaging::NotificationTypes::InvalidDeclarationError,
          /conflicting category_label/,
        )
      end
    end

    context "when category_order conflicts for the same category_key" do
      let(:first) { build_notification_type_declaration(key: "a.type") }
      let(:second) do
        build_notification_type_declaration(
          key: "b.type",
          category_order: 99,
        )
      end

      subject(:invoke) { described_class.validate_category_consistency!(second, peers: [first]) }

      it "rejects conflicting category_order for the same category_key" do
        expect { invoke }.to raise_error(
          CommandTower::Messaging::NotificationTypes::InvalidDeclarationError,
          /conflicting category_order/,
        )
      end
    end
  end
end
