# frozen_string_literal: true

module CommandTower::ServiceLogging
  def self.included(base)
    base.include CommandTower::Execution::ContextAccess
  end
end
