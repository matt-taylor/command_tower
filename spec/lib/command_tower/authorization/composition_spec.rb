# frozen_string_literal: true

RSpec.describe CommandTower::Authorization, :with_rbac_zero do
  let(:host_yaml) { nil }
  let(:host_rbac_file) do
    file = Tempfile.new(["rbac_groups", ".yml"])
    file.write(host_yaml)
    file.flush
    file
  end

  after { host_rbac_file.close! if host_yaml }

  describe "two-source composition" do
    context "when loading the CommandTower source only" do
      before { described_class.provision_rbac_default! }

      it "marks me as CommandTower-owned" do
        expect(described_class::Entity.entities["me"].source).to eq(:command_tower)
      end

      it "maps me to MeController" do
        expect(described_class::Entity.entities["me"].controller).to eq(CommandTower::MeController)
      end

      it "marks owner as CommandTower-owned" do
        expect(described_class::Role.roles["owner"].source).to eq(:command_tower)
      end

      it "does not ship an operational admin role" do
        expect(described_class::Role.roles["admin"]).to be_nil
      end
    end

    context "when composing the dummy host file" do
      before { described_class.default_defined! }

      it "defines a host member role" do
        expect(described_class::Role.roles["member"].source).to eq(:host)
      end

      it "grants CT-owned me and inbox entities" do
        expect(described_class::Role.roles["member"].entities.map(&:name)).to include("me", "me_inbox", "me_audit_events")
      end

      it "does not copy entity ownership onto the host" do
        expect(described_class::Role.roles["member"].entities.map(&:source).uniq).to eq([:command_tower])
      end

      it "marks dummy_admin_example as host-owned" do
        expect(described_class::Entity.entities["dummy_admin_example"].source).to eq(:host)
      end

      it "defines host-owned least-privilege Admin operators" do
        expect(described_class::Role.roles["audit_operator"].source).to eq(:host)
        expect(described_class::Role.roles["messaging_operator"].source).to eq(:host)
        expect(described_class::Role.roles["operations_admin"].source).to eq(:host)
        expect(described_class::Role.roles["admin"].source).to eq(:host)
      end

      it "grants audit_operator workspace and audit only" do
      expect(described_class::Role.roles["audit_operator"].entities.map(&:name)).to contain_exactly(
        "principal_capabilities", "admin_workspace", "admin_audit_events"
      )
      end

      it "grants messaging_operator workspace and messaging only" do
      expect(described_class::Role.roles["messaging_operator"].entities.map(&:name)).to contain_exactly(
        "principal_capabilities", "admin_workspace", "admin_messaging_announcements"
      )
      end

      it "does not grant impersonation to the dummy host admin bundle" do
        expect(described_class::Role.roles["admin"].entities.map(&:name)).not_to include("admin_impersonation")
        expect(described_class::Role.roles["operations_admin"].entities.map(&:name)).not_to include("admin_impersonation")
      end

      it "grants impersonation_operator users and impersonation" do
        expect(described_class::Role.roles["impersonation_operator"].entities.map(&:name)).to contain_exactly(
          "principal_capabilities", "admin_workspace", "admin_users", "admin_impersonation"
        )
      end
    end

    context "when the host adds its own entity and grants CT me" do
      before do
        stub_const("HostOwned::ExampleController", host_controller)
        allow(CommandTower.config.authorization).to receive(:rbac_group_path).and_return(host_rbac_file.path)
        described_class.provision_rbac_default!
        described_class.provision_rbac_user_defined!
      end

      let(:host_controller) do
        Class.new(CommandTower::ApplicationController).tap do |klass|
          klass.define_method(:show) { nil }
        end
      end
      let(:host_yaml) do
        <<~YAML
          groups:
            member:
              description: Host member
              entities:
                - me
                - host_example
          entities:
            - name: host_example
              controller: HostOwned::ExampleController
              only: show
        YAML
      end

      it "keeps me CommandTower-owned" do
        expect(described_class::Entity.entities["me"].source).to eq(:command_tower)
      end

      it "records the host entity as host-owned" do
        expect(described_class::Entity.entities["host_example"].source).to eq(:host)
      end

      it "lets member grant both entities" do
        expect(described_class::Role.roles["member"].entities.map(&:name)).to include("me", "host_example")
      end
    end

    context "when the host redefines a CT entity name" do
      subject(:compose_host) { described_class.provision_rbac_user_defined! }

      before do
        allow(CommandTower.config.authorization).to receive(:rbac_group_path).and_return(host_rbac_file.path)
        described_class.provision_rbac_default!
      end

      let(:host_yaml) do
        <<~YAML
          entities:
            - name: me
              controller: CommandTower::MeController
              only: show
        YAML
      end

      it "fails at composition" do
        expect { compose_host }.to raise_error(
          CommandTower::Authorization::Error,
          /already exists/
        )
      end
    end

    context "when the host redefines the CT owner role" do
      subject(:compose_host) { described_class.provision_rbac_user_defined! }

      before do
        allow(CommandTower.config.authorization).to receive(:rbac_group_path).and_return(host_rbac_file.path)
        described_class.provision_rbac_default!
      end

      let(:host_yaml) do
        <<~YAML
          groups:
            owner:
              description: Host attempt to replace owner
              entities:
                - me
        YAML
      end

      it "fails at composition" do
        expect { compose_host }.to raise_error(
          CommandTower::Authorization::Error,
          /already exists/
        )
      end
    end

    context "when the host defines an operational admin role" do
      before do
        allow(CommandTower.config.authorization).to receive(:rbac_group_path).and_return(host_rbac_file.path)
        described_class.provision_rbac_default!
        described_class.provision_rbac_user_defined!
      end

      let(:host_yaml) do
        <<~YAML
          groups:
            admin:
              description: Host-owned deliberate Admin bundle
              entities:
                - admin_workspace
                - admin_audit_events
                - admin_messaging_announcements
        YAML
      end

      it "accepts host-owned admin as host policy" do
        expect(described_class::Role.roles["admin"].source).to eq(:host)
        expect(described_class::Role.roles["admin"].entities.map(&:name)).to contain_exactly(
          "admin_workspace", "admin_audit_events", "admin_messaging_announcements"
        )
      end
    end

    context "when a host role combines CT and host-owned entities" do
      before do
        stub_const("HostOwned::SupportController", host_controller)
        allow(CommandTower.config.authorization).to receive(:rbac_group_path).and_return(host_rbac_file.path)
        described_class.provision_rbac_default!
        described_class.provision_rbac_user_defined!
      end

      let(:host_controller) do
        Class.new(CommandTower::ApplicationController).tap do |klass|
          klass.define_method(:show) { nil }
        end
      end
      let(:host_yaml) do
        <<~YAML
          groups:
            support_admin:
              description: Mixed CT and host grants
              entities:
                - admin_workspace
                - admin_audit_events
                - host_support_tools
          entities:
            - name: host_support_tools
              controller: HostOwned::SupportController
              only: show
        YAML
      end

      it "composes CT and host entities on the host role" do
        expect(described_class::Role.roles["support_admin"].source).to eq(:host)
        expect(described_class::Role.roles["support_admin"].entities.map(&:name)).to contain_exactly(
          "admin_workspace", "admin_audit_events", "host_support_tools"
        )
        expect(described_class::Entity.entities["host_support_tools"].source).to eq(:host)
        expect(described_class::Entity.entities["admin_workspace"].source).to eq(:command_tower)
      end
    end

    context "when a group references an unknown entity" do
      subject(:compose_host) { described_class.provision_rbac_user_defined! }

      before do
        allow(CommandTower.config.authorization).to receive(:rbac_group_path).and_return(host_rbac_file.path)
        described_class.provision_rbac_default!
      end

      let(:host_yaml) do
        <<~YAML
          groups:
            member:
              description: Broken grant
              entities:
                - not_a_real_entity
        YAML
      end

      it "fails at composition" do
        expect { compose_host }.to raise_error(
          CommandTower::Authorization::Error,
          /unknown entity/
        )
      end
    end

    context "when groups are malformed" do
      subject(:compose_host) { described_class.provision_rbac_user_defined! }

      before do
        allow(CommandTower.config.authorization).to receive(:rbac_group_path).and_return(host_rbac_file.path)
        described_class.provision_rbac_default!
      end

      let(:host_yaml) do
        <<~YAML
          groups:
            - member
        YAML
      end

      it "fails closed" do
        expect { compose_host }.to raise_error(
          CommandTower::Authorization::Error,
          /groups must be a mapping/
        )
      end
    end

    context "when the host only grants CT entity names" do
      before do
        described_class.provision_rbac_default!
        allow(CommandTower.config.authorization).to receive(:rbac_group_path).and_return(host_rbac_file.path)
        described_class.provision_rbac_user_defined!
      end

      let(:host_yaml) do
        <<~YAML
          groups:
            member:
              description: Grants only
              entities:
                - me
        YAML
      end

      it "keeps CT entity ownership" do
        expect(described_class::Entity.entities["me"].source).to eq(:command_tower)
      end
    end

    context "when composing the same sources twice" do
      let!(:first_signature) do
        described_class.default_defined!
        [
          described_class::Entity.entities.keys.map(&:to_s).sort,
          described_class::Role.roles.keys.map(&:to_s).sort,
          described_class::Role.roles["member"].entities.map { |entity| entity.name.to_s }.sort
        ]
      end

      context "after reloading the same sources" do
        before { described_class.default_defined! }

        it "keeps the same entity names" do
          expect(described_class::Entity.entities.keys.map(&:to_s).sort).to eq(first_signature[0])
        end

        it "keeps the same role names" do
          expect(described_class::Role.roles.keys.map(&:to_s).sort).to eq(first_signature[1])
        end

        it "keeps the same member grants" do
          expect(described_class::Role.roles["member"].entities.map { |entity| entity.name.to_s }.sort).to eq(first_signature[2])
        end
      end
    end
  end

  describe ".validate_default_membership_role!" do
    before { described_class.default_defined! }

    context "when default_membership_role is nil" do
      before { allow(CommandTower.config.authorization).to receive(:default_membership_role).and_return(nil) }

      it "allows nil" do
        expect { described_class.validate_default_membership_role! }.not_to raise_error
      end
    end

    context "when default_membership_role is member" do
      before { allow(CommandTower.config.authorization).to receive(:default_membership_role).and_return("member") }

      it "allows member when the composed graph defines it" do
        expect { described_class.validate_default_membership_role! }.not_to raise_error
      end
    end

    context "when default_membership_role is unknown" do
      before { allow(CommandTower.config.authorization).to receive(:default_membership_role).and_return("not_a_role") }

      it "fails during validation" do
        expect { described_class.validate_default_membership_role! }.to raise_error(
          CommandTower::Authorization::Error,
          /not present in the composed RBAC graph/
        )
      end
    end
  end
end
