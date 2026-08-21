# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Admin::Messaging::CreateAnnouncementWorkflow, :messaging_accept do
  describe ".call" do
    let(:admin) { create(:user, :role_admin) }
    let(:targets) { create_list(:user, 2) }
    let(:input) do
      CommandTower::Deserializers::Admin::Messaging::CreateAnnouncementDeserializer::Input.new(
        title: "You're invited",
        body: "Book here: secret-body",
        notification_type_key: "promotional_announcement",
        campaign_identity: "admin/promo/1",
        audience: :user_ids,
        user_ids: targets.map(&:id),
        execution_mode: :sync,
        metadata: nil
      )
    end

    before do
      register_and_seal_notification_types(
        build_notification_type_declaration(
          key: "promotional_announcement",
          allowed_channels: %w[email sms],
          default_channels: %w[email sms],
          inbox_available: true,
          user_configurable: true,
          mandatory: false,
          default_preference_state: {
            "channels" => { "email" => true, "sms" => true },
            "inbox" => true
          }
        )
      )
      allow(CommandTower.config.messaging).to receive(:platform_enabled_channels).and_return(-> { %w[email sms] })
      allow(CommandTower.config.messaging).to receive(:resolve_announcement_audience).and_return(
        lambda { |selection|
          selection = selection.with_indifferent_access
          case selection[:mode]&.to_sym
          when :user_ids then Array(selection[:ids]).map(&:to_i)
          when :all_users then User.pluck(:id)
          else []
          end
        }
      )
    end

    context "when produce succeeds" do
      before do
        CommandTower.with_execution(source: :http, user_id: admin.id, effective_user_id: admin.id) do
          described_class.call(input:)
        end
      end

      let(:row) { CommandTower::Audit::Event.find_by!(action: "announcement_produced") }

      it "persists announcement_produced as admin_direct without the body" do
        expect(row.attribution_mode).to eq("admin_direct")
        expect(row.actor_user_id).to eq(admin.id)
        expect(row.affected_user_id).to be_nil
        expect(row.user_history).to eq(false)
        expect(row.metadata).to eq(
          "campaign_identity" => "admin/promo/1",
          "notification_type_key" => "promotional_announcement",
          "recipient_count" => 2
        )
        expect(row.metadata.to_s).not_to include("secret-body")
      end
    end
  end
end
