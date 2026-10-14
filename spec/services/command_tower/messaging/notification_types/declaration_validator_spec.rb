# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::NotificationTypes::DeclarationValidator,
               :messaging_notification_types do
  describe ".validate" do
    subject(:errors) { described_class.validate(declaration) }

    let(:declaration) { build_notification_type_declaration }
    let(:permitted_choice) { CommandTower::Messaging::NotificationTypes::PermittedChoice }
    let(:normal_urgency) { permitted_choice.new(default: "normal", allowed: %w[normal].freeze) }
    let(:default_sound) { permitted_choice.new(default: "default", allowed: %w[default].freeze) }

    context "when the declaration is valid" do
      it "returns no errors" do
        expect(errors).to be_empty
      end
    end

    context "when a push type is inbox-backed" do
      let(:declaration) do
        build_notification_type_declaration(
          allowed_channels: %w[push],
          default_channels: %w[push],
          inbox_available: true,
          default_preference_state: { "channels" => { "push" => true }, "inbox" => true },
        )
      end

      it "returns no errors" do
        expect(errors).to be_empty
      end
    end

    context "when a push type declares deep_link_required" do
      let(:declaration) do
        build_notification_type_declaration(
          allowed_channels: %w[push],
          default_channels: %w[push],
          inbox_available: false,
          deep_link_required: true,
          default_preference_state: { "channels" => { "push" => true }, "inbox" => false },
        )
      end

      it "returns no errors" do
        expect(errors).to be_empty
      end
    end

    context "when a push type is neither inbox-backed nor deep_link_required" do
      let(:declaration) do
        build_notification_type_declaration(
          allowed_channels: %w[push],
          default_channels: %w[push],
          inbox_available: false,
          default_preference_state: { "channels" => { "push" => true }, "inbox" => false },
        )
      end

      it "rejects the declaration" do
        expect(errors).to include(
          "push-capable types must be inbox-backed or declare deep_link_required",
        )
      end
    end

    context "when urgency is a valid restricted choice" do
      let(:declaration) do
        build_notification_type_declaration(urgency: { default: "normal", allowed: %w[normal time_sensitive] })
      end

      it "returns no errors" do
        expect(errors).to be_empty
      end
    end

    context "when urgency is the full catalog" do
      let(:declaration) { build_notification_type_declaration(urgency: { default: "normal", allowed: "all" }) }

      it "returns no errors" do
        expect(errors).to be_empty
      end
    end

    context "when sound is a valid restricted choice" do
      let(:declaration) do
        build_notification_type_declaration(sound: { default: "default", allowed: %w[default chime] })
      end

      it "returns no errors" do
        expect(errors).to be_empty
      end
    end

    context "when sound is the full catalog" do
      let(:declaration) { build_notification_type_declaration(sound: { default: "chime", allowed: "all" }) }

      it "returns no errors" do
        expect(errors).to be_empty
      end
    end

    context "when urgency names an unknown level" do
      let(:declaration) { build_notification_type_declaration(urgency: { default: "loud" }) }

      it "rejects the level" do
        expect(errors).to include('urgency has unknown urgency level: "loud"')
      end
    end

    context "when urgency is not a hash" do
      let(:declaration) { build_notification_type_declaration(urgency: "normal") }

      it "rejects the value" do
        expect(errors).to include("urgency must be a hash with default and allowed")
      end
    end

    context "when urgency has no default" do
      let(:declaration) { build_notification_type_declaration(urgency: { allowed: %w[normal] }) }

      it "rejects the missing default" do
        expect(errors).to include("urgency default must be present")
      end
    end

    context "when the urgency default is not permitted" do
      let(:declaration) do
        build_notification_type_declaration(urgency: { default: "critical", allowed: %w[normal time_sensitive] })
      end

      it "rejects a default outside allowed" do
        expect(errors).to include("urgency default must be one of allowed")
      end
    end

    context "when urgency allowed is empty" do
      let(:declaration) { build_notification_type_declaration(urgency: { default: "normal", allowed: [] }) }

      it "rejects an empty list" do
        expect(errors).to include('urgency allowed must be "all" or a non-empty array')
      end
    end

    context "when urgency allowed has duplicates" do
      let(:declaration) do
        build_notification_type_declaration(urgency: { default: "normal", allowed: %w[normal normal] })
      end

      it "rejects duplicates" do
        expect(errors).to include("urgency allowed contains duplicates")
      end
    end

    context "when a sound id is malformed" do
      let(:declaration) { build_notification_type_declaration(sound: { default: "Chime Bell" }) }

      it "rejects the id" do
        expect(errors).to include('sound has malformed sound id: "Chime Bell"')
      end
    end

    context "when sound allowed is not \"all\" or an array" do
      let(:declaration) { build_notification_type_declaration(sound: { default: "default", allowed: 5 }) }

      it "rejects the value" do
        expect(errors).to include('sound allowed must be "all" or a non-empty array')
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
          inbox_document_composer: nil,
          badge_eligible: false,
          urgency: normal_urgency,
          sound: default_sound,
          deep_link_required: false,
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
          inbox_document_composer: nil,
          badge_eligible: false,
          urgency: normal_urgency,
          sound: default_sound,
          deep_link_required: false,
        )
      end

      it "rejects a non-boolean settings_visible" do
        expect(errors).to include("settings_visible must be a boolean")
      end
    end
  end

  describe ".sound_reference_errors" do
    subject(:errors) { described_class.sound_reference_errors(declaration, catalog_ids: %w[default chime]) }

    context "when every named sound is registered" do
      let(:declaration) do
        build_notification_type_declaration(sound: { default: "default", allowed: %w[default chime] })
      end

      it "returns no errors" do
        expect(errors).to be_empty
      end
    end

    context "when the type uses the full catalog with a registered default" do
      let(:declaration) { build_notification_type_declaration(sound: { default: "chime", allowed: "all" }) }

      it "returns no errors" do
        expect(errors).to be_empty
      end
    end

    context "when an allowed sound is not registered" do
      let(:declaration) do
        build_notification_type_declaration(sound: { default: "default", allowed: %w[default bell] })
      end

      it "names the missing id" do
        expect(errors).to eq(["sound references unregistered sound ids: bell"])
      end
    end

    context "when the default sound is not registered" do
      let(:declaration) { build_notification_type_declaration(sound: { default: "bell", allowed: "all" }) }

      it "names the missing default" do
        expect(errors).to eq(["sound references unregistered sound ids: bell"])
      end
    end

    context "when the sound is not a permitted choice" do
      let(:declaration) { build_notification_type_declaration(sound: "default") }

      it "leaves the report to .validate" do
        expect(errors).to be_empty
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
