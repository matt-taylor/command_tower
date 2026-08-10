# frozen_string_literal: true

module CommandTower
  module Clients
    class ClientResult
      attr_reader :output, :error, :metadata, :provider_metadata

      def initialize(success:, output:, error:, metadata:, provider_metadata: {})
        @success = success
        @output = output
        @error = error
        @metadata = metadata
        @provider_metadata = provider_metadata
      end

      def success?
        @success
      end

      def failure?
        !success?
      end

      def self.success(output:, metadata: {}, provider_metadata: {})
        new(
          success: true,
          output: output,
          error: nil,
          metadata: metadata,
          provider_metadata: provider_metadata
        )
      end

      def self.failure(error:, output: nil, metadata: {}, provider_metadata: {})
        new(
          success: false,
          output: output,
          error: error,
          metadata: metadata,
          provider_metadata: provider_metadata
        )
      end
    end
  end
end
