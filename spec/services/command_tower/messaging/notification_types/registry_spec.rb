# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::NotificationTypes::Registry,
               :messaging_notification_types do
  subject(:registry) { described_class.instance }

  describe "#register and #seal" do
    context "with a valid declaration" do
      let(:declaration) { build_notification_type_declaration(key: "booking.success") }

      it "registers a valid declaration while open" do
        expect(registry.register(declaration)).to eq(declaration)
        expect(registry.registered?("booking.success")).to be(true)
      end
    end

    context "with a duplicate key" do
      let(:declaration) { build_notification_type_declaration(key: "booking.success") }

      before { registry.register(declaration) }

      it "rejects duplicate keys" do
        expect {
          registry.register(build_notification_type_declaration(key: "booking.success"))
        }.to raise_error(CommandTower::Messaging::NotificationTypes::DuplicateTypeError)
      end
    end

    it "rejects invalid declarations without inserting them" do
      expect {
        registry.register(build_notification_type_declaration(key: ""))
      }.to raise_error(CommandTower::Messaging::NotificationTypes::InvalidDeclarationError)

      expect(registry.enumerate).to be_empty
    end

    it "rejects declarations with unknown channel keys before seal" do
      expect {
        registry.register(build_notification_type_declaration(allowed_channels: %w[fax]))
      }.to raise_error(CommandTower::Messaging::NotificationTypes::InvalidDeclarationError)

      expect(registry.enumerate).to be_empty
    end

    it "rejects declarations with inbox in allowed_channels before seal" do
      expect {
        registry.register(build_notification_type_declaration(allowed_channels: %w[inbox email]))
      }.to raise_error(CommandTower::Messaging::NotificationTypes::InvalidDeclarationError)

      expect(registry.enumerate).to be_empty
    end

    context "with a DFM-like email-only declaration" do
      let(:declaration) do
        build_notification_type_declaration(
          key: "booking.confirmation",
          allowed_channels: %w[email],
          default_channels: %w[email],
          default_preference_state: { "channels" => { "email" => true }, "inbox" => true },
        )
      end

      before do
        registry.register(declaration)
        registry.seal
      end

      it "registers and seals DFM-like email-only declarations" do
        expect(registry.lookup("booking.confirmation").allowed_channels).to eq(%w[email])
      end
    end

    context "with an inbox-only declaration" do
      let(:declaration) do
        build_notification_type_declaration(
          key: "waitlist.promotion",
          allowed_channels: [],
          default_channels: [],
          default_preference_state: { "channels" => {}, "inbox" => true },
        )
      end

      before do
        registry.register(declaration)
        registry.seal
      end

      it "registers and seals inbox-only declarations with empty channel lists" do
        expect(registry.sealed?).to be(true)
      end
    end

    it "rejects conflicting category metadata for the same category_key" do
      registry.register(build_notification_type_declaration(key: "booking.success"))

      expect {
        registry.register(
          build_notification_type_declaration(
            key: "booking.reminder",
            category_label: "Other",
          ),
        )
      }.to raise_error(
        CommandTower::Messaging::NotificationTypes::InvalidDeclarationError,
        /conflicting category_label/,
      )

      expect(registry.registered?("booking.reminder")).to be(false)
    end

    context "after seal" do
      before do
        registry.register(build_notification_type_declaration(key: "booking.success"))
        registry.seal
      end

      it "rejects register after seal" do
        expect {
          registry.register(build_notification_type_declaration(key: "booking.reminder"))
        }.to raise_error(CommandTower::Messaging::NotificationTypes::SealedRegistryError)
      end
    end

    it "seals a consistent catalog" do
      registry.register(build_notification_type_declaration(key: "booking.success"))
      expect(registry.seal).to be(true)
      expect(registry.sealed?).to be(true)
    end
  end

  describe "#lookup / #registered? / #enumerate" do
    before do
      registry.register(build_notification_type_declaration(key: "booking.success"))
      registry.register(build_notification_type_declaration(key: "booking.reminder", type_order: 20))
      registry.seal
    end

    it "returns the declaration on lookup hit" do
      expect(registry.lookup("booking.success").key).to eq("booking.success")
    end

    it "raises NotFoundError on lookup miss" do
      expect {
        registry.lookup("unknown.type")
      }.to raise_error(CommandTower::Messaging::NotificationTypes::NotFoundError)
    end

    it "reports registration with registered?" do
      expect(registry.registered?("booking.success")).to be(true)
      expect(registry.registered?("unknown.type")).to be(false)
    end

    it "enumerates all registered declarations in registration order" do
      expect(registry.enumerate.map(&:key)).to eq(["booking.success", "booking.reminder"])
    end

    it "preserves enumerate insertion order independent of catalog sort" do
      CommandTower::Messaging::NotificationTypes.reset!

      described_class.instance.tap do |open_registry|
        open_registry.register(
          build_notification_type_declaration(
            key: "z.last",
            category_key: "beta",
            category_label: "Beta",
            category_order: 20,
            type_order: 10,
          ),
        )
        open_registry.register(
          build_notification_type_declaration(
            key: "a.first",
            category_key: "alpha",
            category_label: "Alpha",
            category_order: 10,
            type_order: 10,
          ),
        )
        open_registry.seal

        expect(open_registry.enumerate.map(&:key)).to eq(["z.last", "a.first"])
        expect(open_registry.catalog.map(&:key)).to eq(%w[alpha beta])
      end
    end
  end

  describe "#catalog" do
    before do
      registry.register(
        build_notification_type_declaration(
          key: "promo.announce",
          label: "Promotional Announcement",
          category_key: "marketing",
          category_label: "Marketing",
          category_order: 40,
          type_order: 10,
        ),
      )
      registry.register(
        build_notification_type_declaration(
          key: "booking.cancel",
          label: "Booking Cancellation",
          category_key: "reservations",
          category_label: "Reservations",
          category_order: 10,
          type_order: 20,
        ),
      )
      registry.register(
        build_notification_type_declaration(
          key: "booking.confirm",
          label: "Booking Confirmation",
          category_key: "reservations",
          category_label: "Reservations",
          category_order: 10,
          type_order: 10,
        ),
      )
      registry.seal
    end

    subject(:catalog) { registry.catalog }

    it "returns an immutable grouped catalog in deterministic order" do
      expect(catalog).to be_frozen
      expect(catalog.map(&:key)).to eq(%w[reservations marketing])
      expect(catalog.first.declarations.map(&:key)).to eq(%w[booking.confirm booking.cancel])
      expect(catalog.first).to be_frozen
      expect(catalog.first.declarations).to be_frozen

      expect {
        catalog << "mutated"
      }.to raise_error(FrozenError)
      expect(registry.catalog.map(&:key)).to eq(%w[reservations marketing])
    end

    context "with category and type key tie-breakers" do
      before do
        CommandTower::Messaging::NotificationTypes.reset!
        described_class.instance.tap do |open_registry|
          open_registry.register(
            build_notification_type_declaration(
              key: "b.type",
              category_key: "beta",
              category_label: "Beta",
              category_order: 10,
              type_order: 10,
            ),
          )
          open_registry.register(
            build_notification_type_declaration(
              key: "a.type",
              category_key: "alpha",
              category_label: "Alpha",
              category_order: 10,
              type_order: 10,
            ),
          )
          open_registry.register(
            build_notification_type_declaration(
              key: "c.type",
              category_key: "alpha",
              category_label: "Alpha",
              category_order: 10,
              type_order: 10,
            ),
          )
          open_registry.seal
        end
      end

      it "uses category_key then type key as ordering tie-breakers" do
        expect(described_class.instance.catalog.map(&:key)).to eq(%w[alpha beta])
        expect(described_class.instance.catalog.first.declarations.map(&:key)).to eq(%w[a.type c.type])
      end
    end
  end
end

RSpec.describe CommandTower::Messaging::NotificationTypes, :messaging_notification_types do
  describe "module façade" do
    let(:declaration) { build_notification_type_declaration(key: "booking.success") }

    before do
      described_class.register(declaration)
      described_class.seal
    end

    it "delegates register, seal, lookup, registered?, enumerate, and catalog" do
      expect(described_class.registered?("booking.success")).to be(true)
      expect(described_class.lookup("booking.success")).to eq(declaration)
      expect(described_class.enumerate.map(&:key)).to eq(["booking.success"])
      expect(described_class.catalog.map(&:key)).to eq(["example"])
      expect(described_class.catalog.first.declarations.map(&:key)).to eq(["booking.success"])
    end

    it "supports register_and_seal helper for fixtures" do
      register_and_seal_notification_types(
        build_notification_type_declaration(key: "a.type"),
        build_notification_type_declaration(key: "b.type"),
      )

      expect(described_class.enumerate.map(&:key)).to contain_exactly("a.type", "b.type")
      expect(described_class::Registry.instance.sealed?).to be(true)
    end
  end
end
