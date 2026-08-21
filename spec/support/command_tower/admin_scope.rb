# frozen_string_literal: true

module CommandTower
  module AdminScopeSpecHelper
    def reset_admin_scope_registrations!
      return unless CommandTower.config.respond_to?(:admin_scope)

      CommandTower.config.admin_scope.reset_registrations!
    end
  end
end

RSpec.configure do |config|
  config.include CommandTower::AdminScopeSpecHelper
  config.after { reset_admin_scope_registrations! }
end
