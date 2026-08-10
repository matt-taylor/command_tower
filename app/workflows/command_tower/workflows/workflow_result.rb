# frozen_string_literal: true

module CommandTower
  module Workflows
    class WorkflowResult
      attr_reader :payload, :errors, :http_status, :response_effects, :meta

      def initialize(success:, payload:, errors:, http_status:, response_effects: nil, meta: {})
        @success = success
        @payload = payload
        @errors = errors
        @http_status = http_status
        @response_effects = response_effects
        @meta = meta
      end

      def success?
        @success
      end

      def failure?
        !success?
      end

      def self.success(payload:, http_status: :ok, response_effects: nil, meta: {})
        new(success: true, payload:, errors: [], http_status:, response_effects:, meta:)
      end

      def self.failure(errors:, http_status:, response_effects: nil, meta: {})
        new(success: false, payload: nil, errors:, http_status:, response_effects:, meta:)
      end
    end
  end
end
