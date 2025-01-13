# frozen_string_literal: true

require "interactor"

class ApiEngineBase::ServiceBase
  class ServiceBaseError < ApiEngineBase::Error; end;
  class ValidationError < ServiceBaseError; end;
  class ConfigurationError < ServiceBaseError; end;

  class NameConflictError < ApiEngineBase::Error; end
  class DefaultValueError < ApiEngineBase::Error; end
  class OneOfError < ApiEngineBase::Error; end
  class NestedOneOfError < ApiEngineBase::Error; end
  class ArgumentValidationError < ApiEngineBase::Error; end

  class KeyValidationError < ApiEngineBase::ServiceBase::ValidationError; end
  class CompositionValidationError < ApiEngineBase::ServiceBase::ValidationError; end

  include Interactor
  include ApiEngineBase::ServiceLogging
  include ApiEngineBase::ArgumentValidation

  ON_ARGUMENT_VALIDATION = [
    DEFAULT_VALIDATION = :raise,
    :fail_early,
    :log,
  ]

  def self.inherited(subclass)
    # Add the base logging to the subclass.
    # Since this is done at inheritance time it should always be the first and last hook to run.
    subclass.around(:service_base_logging)
    subclass.around(:internal_validate)
    subclass.after(:sanitize_params)
  end

  def validate!
    # overload from child
  end

  def internal_validate(interactor)
    # call validate that is overridden from child
    begin
      validate! # custom validations defined on the child class
      run_validations! # ArgumentValidation's based on defined settings on child
    rescue StandardError => e
      log_error("Error during validation. #{e.message}")
      raise
    end

    # call interactor
    interactor.call
  end

  def service_base_logging(interactor)
    beginning_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    # Pre processing stats
    log_info("Start")

    # Run the job!
    interactor.call

    # Set status for use in ensure block
    status = :complete

  # Capture Interactor::Failure for logging purposes, then reraise
  rescue ::Interactor::Failure
    # set status for use in ensure block
    status = :failure

    # Re-raise to let the core Interactor handle this
    raise
  # Capture exception explicitly for logging purposes, then reraise
  rescue ::Exception => e
    # set status for use in ensure block
    status = :error

    # Log error
    log_error("Error #{e.class.name}")

    raise
  ensure
    # Always log how long it took along with a status
    finished_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    elapsed = ((finished_time - beginning_time) * 1000).round(2)
    log_info("Finished with [#{status}]...elapsed #{elapsed}ms")
  end
end
