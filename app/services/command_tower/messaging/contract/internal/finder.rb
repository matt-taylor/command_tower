# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Internal
        class Finder
          def self.call(request)
            new(request).call
          end

          def initialize(request)
            @request = request
          end

          def call
            validate_request!

            scope = Messaging::Communication.includes(
              :destination_plan,
              :inbox_item,
              channel_deliveries: :delivery_attempts,
            )
            scope = scope.where(user_id: request.recipient_id) unless request.recipient_id.nil?

            communication = scope.find_by(id: request.communication_id)
            raise Contract::NotFoundError, "Communication not found" if communication.nil?

            Mappers::CommunicationMapper.to_result(communication)
          end

          private

          attr_reader :request

          def validate_request!
            raise Contract::ValidationError, "communication_id is required" if request.communication_id.nil?
          end
        end
      end
    end
  end
end
