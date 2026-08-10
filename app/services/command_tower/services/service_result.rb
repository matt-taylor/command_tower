# frozen_string_literal: true

module CommandTower
  module Services
    class ServiceResult
      INTERACTOR_INTERNAL_KEYS = %i[error rollback].freeze
      FAILURE_ONLY_KEYS = %i[
        msg
        status
        valid_arguments
        invalid_arguments
        invalid_argument_hash
        invalid_argument_keys
        application_error
        service_metadata
      ].freeze

      attr_reader :data, :errors, :metadata

      def initialize(success:, data:, errors:, metadata:)
        @success = success
        @data = data
        @errors = errors
        @metadata = metadata
      end

      def success?
        @success
      end

      def failure?
        !success?
      end

      def self.success(data: {}, metadata: {})
        new(success: true, data:, errors: [], metadata:)
      end

      def self.failure(errors:, data: {}, metadata: {})
        new(success: false, data:, errors:, metadata:)
      end

      def self.from_interactor_context(context)
        metadata = extract_metadata(context)

        if context.success?
          success(data: extract_success_data(context), metadata: metadata)
        elsif context.application_error
          failure(errors: [context.application_error], metadata: metadata)
        elsif context.invalid_arguments
          failure(
            errors: [
              CommandTower::Errors::ValidationError.new(details: context.invalid_argument_hash)
            ],
            metadata: metadata
          )
        else
          failure(errors: [CommandTower::Errors::InternalError.new], metadata: metadata)
        end
      end

      def self.extract_metadata(context)
        context.service_metadata || {}
      end
      private_class_method :extract_metadata

      def self.extract_success_data(context)
        context.to_h.except(*INTERACTOR_INTERNAL_KEYS, *FAILURE_ONLY_KEYS)
      end
      private_class_method :extract_success_data
    end
  end
end
