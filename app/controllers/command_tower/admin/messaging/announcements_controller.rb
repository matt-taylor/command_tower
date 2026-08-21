# frozen_string_literal: true

module CommandTower
  module Admin
    module Messaging
      class AnnouncementsController < CommandTower::Admin::ApplicationController
        def create
          deserialized = CommandTower::Deserializers::Admin::Messaging::CreateAnnouncementDeserializer.call(params)
          unless deserialized.success?
            return render_application_result(
              CommandTower::Workflows::WorkflowResult.failure(
                errors: [CommandTower::Errors::ValidationError.new(details: { base: "Invalid request parameters" })],
                http_status: :unprocessable_entity
              )
            )
          end

          render_application_result(
            CommandTower::Workflows::Admin::Messaging::CreateAnnouncementWorkflow.call(
              input: deserialized.input
            )
          )
        end
      end
    end
  end
end
