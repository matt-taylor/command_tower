# frozen_string_literal: true

# Sample blocking home notice delivery, pushed to one user by a host workflow. All values are fictional.
class ClassCanceledNotice < CommandTower::HomeNotices::Delivery
  key "studio.class_canceled"
  severity :blocking
  priority 80
  blocking_reason "A booked class was canceled and the member must acknowledge it."
  # Linked to the member's `class_canceled` inbox item: the document is that item's own, and the
  # notice is shown until the item is viewed. Acknowledging marks the item viewed.
  composer :message
end
