# frozen_string_literal: true

module CommandTower
  module InboxPresentationsSpecHelper
    def reset_host_inbox_presentations!
      return unless CommandTower.config.respond_to?(:registry)

      CommandTower.config.registry.inbox_presentations.reset_host_definitions!
    end
  end
end

RSpec.configure do |config|
  config.include CommandTower::InboxPresentationsSpecHelper
  config.after { reset_host_inbox_presentations! }
end
