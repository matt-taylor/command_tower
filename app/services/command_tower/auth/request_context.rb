# frozen_string_literal: true

module CommandTower
  module Auth
    # Transport handle passed from a controller boundary into authentication.
    # Keeps the request/response pair together so services never reach for
    # controller state directly. Not a workflow type.
    class RequestContext
      attr_reader :request, :response

      def self.from(request, response)
        new(request:, response:)
      end

      def initialize(request:, response:)
        @request = request
        @response = response
      end
    end
  end
end
