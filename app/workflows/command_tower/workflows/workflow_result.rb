# frozen_string_literal: true

module CommandTower
  module Workflows
    class WorkflowResult
      STATUSES = %i[success deferred failure].freeze

      attr_reader :payload, :errors, :http_status, :response_effects, :meta, :reason, :retry_after

      def initialize(status:, payload:, errors:, http_status:, response_effects: nil, meta: {},
                     reason: nil, retry_after: nil)
        @status = status.to_sym
        raise ArgumentError, "invalid WorkflowResult status #{@status}" unless STATUSES.include?(@status)

        @payload = payload
        @errors = errors
        @http_status = http_status
        @response_effects = response_effects
        @meta = meta
        @reason = reason
        @retry_after = retry_after
      end

      def success?
        @status == :success
      end

      def deferred?
        @status == :deferred
      end

      def failure?
        @status == :failure
      end

      def self.success(payload:, http_status: :ok, response_effects: nil, meta: {})
        new(status: :success, payload:, errors: [], http_status:, response_effects:, meta:)
      end

      def self.failure(errors:, http_status:, response_effects: nil, meta: {})
        new(status: :failure, payload: nil, errors:, http_status:, response_effects:, meta:)
      end

      def self.deferred(reason:, retry_after:, payload: {}, http_status: :accepted, response_effects: nil, meta: {})
        new(
          status: :deferred,
          payload:,
          errors: [],
          http_status:,
          response_effects:,
          meta:,
          reason: reason.to_sym,
          retry_after: Integer(retry_after)
        )
      end
    end
  end
end
