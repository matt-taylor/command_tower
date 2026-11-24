# frozen_string_literal: true

# Helpers for the admin announcement workflow spec. Reads `type_key`, `title`, `body` and `metadata`
# from the including example group.
module AnnouncementWorkflowHelpers
  def targets
    @targets ||= create_list(:user, 2)
  end

  def result
    @result ||= begin
      admin = create(:user, :role_admin)
      input = CommandTower::Deserializers::Admin::Messaging::CreateAnnouncementDeserializer::Input.new(
        title:, body:, notification_type_key: type_key, campaign_identity: "admin/promo/1",
        audience: :user_ids, user_ids: targets.map(&:id), execution_mode: :sync, metadata:
      )
      CommandTower.with_execution(source: :http, user_id: admin.id, effective_user_id: admin.id) do
        described_class.call(input:)
      end
    end
  end

  def communications
    CommandTower::Messaging::Communication.where(user_id: targets.map(&:id))
  end
end
