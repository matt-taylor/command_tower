# frozen_string_literal: true

# Sample blocking home notice delivery, pushed to one user by a host workflow. All values are fictional.
class ClassCanceledNotice < CommandTower::HomeNotices::Delivery
  key "studio.class_canceled"
  severity :blocking
  priority 80
  blocking_reason "A booked class was canceled and the member must acknowledge it."

  def show?(user:, context:, notice:) # rubocop:disable Lint/UnusedMethodArgument
    true
  end

  def compose(_builder, user:, context:, notice:) # rubocop:disable Lint/UnusedMethodArgument
    nil
  end
end
