# frozen_string_literal: true

module CommandTower
  module Serializers
    module Admin
      module Messaging
        module AnnouncementResponseSerializer
          module_function

          def serialize(data)
            mode = data[:mode]
            base = {
              "mode" => mode.to_s,
              "requested" => data[:requested],
              "campaignIdentity" => data[:campaign_identity],
            }

            if mode == :async
              base.merge(
                "enqueued" => data[:enqueued],
                "enqueueFailed" => data[:enqueue_failed],
              )
            else
              base.merge(
                "accepted" => data[:accepted],
                "failed" => data[:failed],
                "skipped" => data[:skipped],
                "failures" => Array(data[:failures]).map do |failure|
                  {
                    "userId" => failure[:user_id],
                    "errorCode" => failure[:error_code],
                  }
                end
              )
            end
          end
        end
      end
    end
  end
end
