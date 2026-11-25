# frozen_string_literal: true

# Sample blocking home notice campaign that repeats each period. All values are fictional.
class TermsUpdateNotice < CommandTower::HomeNotices::Campaign
  key "studio.terms_update"
  severity :blocking
  priority 90
  blocking_reason "Studio terms changed and the member must accept them each quarter."

  period_key { |user:, context:| Time.current.strftime("%Y-Q#{((Time.current.month - 1) / 3) + 1}") } # rubocop:disable Lint/UnusedBlockArgument

  def show?(user:, context:, notice:) # rubocop:disable Lint/UnusedMethodArgument
    true
  end

  def compose(_builder, user:, context:, notice:) # rubocop:disable Lint/UnusedMethodArgument
    nil
  end
end
