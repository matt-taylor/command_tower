# frozen_string_literal: true

require "interactor"

class CommandTower::ServiceBase
  class ServiceBaseError < CommandTower::Error; end;
  class ValidationError < ServiceBaseError; end;
  class ConfigurationError < ServiceBaseError; end;

  class NameConflictError < CommandTower::Error; end
  class DefaultValueError < CommandTower::Error; end
  class OneOfError < CommandTower::Error; end
  class NestedOneOfError < CommandTower::Error; end
  class ArgumentValidationError < CommandTower::Error; end

  class KeyValidationError < CommandTower::ServiceBase::ValidationError; end
  class CompositionValidationError < CommandTower::ServiceBase::ValidationError; end

  include Interactor
  include CommandTower::ServiceLogging
  include CommandTower::ArgumentValidation
  include CommandTower::Execution::ContextAccess
  include CommandTower::Logging::LifecycleDeclaration

  ON_ARGUMENT_VALIDATION = [
    DEFAULT_VALIDATION = :raise,
    :fail_early,
    :log,
  ]

  def self.inherited(subclass)
    subclass.around(:internal_validate)
    subclass.after(:sanitize_params)
    # Registered last so Interactor treats it as the outermost around (reverse nest).
    subclass.around(:command_tower_lifecycle)
  end

  def validate!
    # overload from child
  end

  def internal_validate(interactor)
    validate! # custom validations defined on the child class
    run_validations! # ArgumentValidation's based on defined settings on child
    interactor.call
  end

  def command_tower_lifecycle(interactor)
    CommandTower::Events.around_execution(layer: :service, subject: self.class.name, log_lifecycle: self.class.lifecycle_loggable?) do |record|
      begin
        interactor.call
        record[:result] = :success
      rescue ::Interactor::Failure
        record[:result] = :failure
        record[:error_codes] = service_lifecycle_error_codes
        record[:log_level] = service_lifecycle_log_level
        raise
      rescue ::Exception => e
        record[:unexpected] = e
        raise
      end
    end
  end

  def service_lifecycle_error_codes
    error = context.application_error if context.respond_to?(:application_error)
    return [error.code] if error.respond_to?(:code)

    nil
  end

  def service_lifecycle_log_level
    error = context.application_error if context.respond_to?(:application_error)
    error.log_level if error.respond_to?(:log_level)
  end
end
