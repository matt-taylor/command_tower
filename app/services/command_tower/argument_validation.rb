# frozen_string_literal: true

module CommandTower::ArgumentValidation
  class NameConflictError < CommandTower::ServiceBase::ConfigurationError; end
  class NestedDuplicateTypeError < CommandTower::ServiceBase::ConfigurationError; end

  def self.included(base)
    base.extend(CommandTower::ArgumentValidation::ClassMethods)
    base.include(CommandTower::ArgumentValidation::InstanceMethods)
  end
end
