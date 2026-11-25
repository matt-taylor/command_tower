# frozen_string_literal: true

# Sample dismissible home notice campaign. All values are fictional.
class StudioTipsNotice < CommandTower::HomeNotices::Campaign
  key "studio.tips"
  severity :dismissible
  priority 20
  impressions max: 3, cooldown: 12.hours

  def show?(user:, context:, notice:) # rubocop:disable Lint/UnusedMethodArgument
    true
  end

  def compose(_builder, user:, context:, notice:) # rubocop:disable Lint/UnusedMethodArgument
    nil
  end
end
