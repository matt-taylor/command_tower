# frozen_string_literal: true

# Helpers for HomeNotices::Compose specs. Example groups cannot define `def`
# helpers (test standards guard), so shared logic lives here.
module HomeNoticeSpecHelpers
  module_function

  # A campaign whose compose body is the given block.
  def notice_with(kind: :blocking, &body)
    Class.new(CommandTower::HomeNotices::Campaign) do
      key "test.terms"
      severity kind
      priority 10
      blocking_reason "Terms changed and need acceptance"
      define_method(:compose) { |builder, **| instance_exec(builder, &body) }
    end
  end

  def terms_notice
    notice_with do |builder|
      builder.card do |card|
        card.text "Terms updated"
        card.text "Please review them."
      end
    end
  end

  def code_notice
    notice_with do |builder|
      builder.card do |card|
        card.text "Check in"
        card.code(value: "SECRET123", label: "Code", format: "text")
      end
    end
  end

  def raising_notice
    notice_with { |_builder| raise "boom with secret" }
  end

  def internal_link_notice(**)
    notice_with(**) do |builder|
      builder.card { |card| card.button "Go", action: card.navigate(path: "/settings") }
    end
  end

  def different_notice
    notice_with { |builder| builder.card { |card| card.text "Different" } }
  end

  def compose(klass, user:, ui_catalog: 2, impersonating: false)
    request_context = CommandTower::HomeNotices::Context.new(
      now: Time.utc(2026, 1, 1), time_zone: "UTC", app_version: nil, platform: "web",
      ui_catalog:, client_compatibility: nil, impersonating:
    )
    CommandTower::Services::HomeNotices::Compose.call(notice_class: klass, user:, request_context:, record: nil)
  end

  def document_json(result)
    result.data[:document].as_json.to_json
  end
end
