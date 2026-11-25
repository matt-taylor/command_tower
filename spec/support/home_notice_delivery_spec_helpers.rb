# frozen_string_literal: true

# Builders for the Delivery and Deliver specs. Example groups cannot define `def` helpers (test
# standards guard), so the setup lives here.
module HomeNoticeDeliverySpecHelpers
  module_function

  def delivery_class(linked: true)
    Class.new(CommandTower::HomeNotices::Delivery) do
      key "dfm.class_canceled"
      severity :dismissible
      priority 10
      composer :message if linked
    end
  end

  # `Delivery#show?` for a persisted delivery row of `user` linked to `communication_id`.
  def shown?(klass, user:, communication_id:)
    notice = communication_id && CommandTower::HomeNotices::NoticeRecord.from(
      CommandTower::HomeNotice.create!(
        user:, kind: "delivery", key: klass.key, identity: "x/#{user.id}", communication_id:
      )
    )
    klass.new.show?(user:, context: nil, notice:)
  end

  def deliver(user:, notice:, **)
    CommandTower::Services::HomeNotices::Deliver.call(
      user:, notice:, identity: "dfm.class_canceled/1/#{user.id}", **
    )
  end

  def compose_linked(klass, user:, record:, impersonating: false)
    request_context = CommandTower::HomeNotices::Context.new(
      now: Time.utc(2026, 1, 1), time_zone: "UTC", app_version: nil, platform: "web",
      ui_catalog: 2, client_compatibility: nil, impersonating:
    )
    CommandTower::Services::HomeNotices::Compose.call(notice_class: klass, user:, request_context:, record:)
  end

  def identity_for(user)
    "dfm.class_canceled/1/#{user.id}"
  end

  def open_row(user:, identity: "other/1")
    CommandTower::HomeNotice.create!(user:, kind: "delivery", key: "other.notice", identity:)
  end
end
