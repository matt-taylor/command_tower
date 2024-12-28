# frozen_string_literal: true

module ApiEngineBase::ArgumentValidation
  class NameConflictError < ApiEngineBase::ServiceBase::ConfigurationError; end
  class NestedDuplicateTypeError < ApiEngineBase::ServiceBase::ConfigurationError; end

  def self.included(base)
    base.extend(ApiEngineBase::ArgumentValidation::ClassMethods)
    base.include(ApiEngineBase::ArgumentValidation::InstanceMethods)
  end
end
