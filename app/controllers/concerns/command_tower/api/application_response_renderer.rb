# frozen_string_literal: true

module CommandTower
  module Api
    module ApplicationResponseRenderer
      extend ActiveSupport::Concern

      private

      def render_application_result(result)
        apply_response_effects(result.response_effects)
        body = if result.success?
                 CommandTower::Serializers::Application::EnvelopeSerializer.success(
                   data: result.payload,
                   meta: result.meta
                 )
               elsif result.deferred?
                 CommandTower::Serializers::Application::EnvelopeSerializer.success(
                   data: result.payload,
                   meta: result.meta.merge(reason: result.reason, retry_after: result.retry_after)
                 )
               else
                 serialized_errors = result.errors.map do |error|
                   CommandTower::Serializers::Application::ErrorEntrySerializer.serialize(error)
                 end
                 CommandTower::Serializers::Application::EnvelopeSerializer.failure(
                   errors: serialized_errors,
                   meta: result.meta
                 )
               end
        render json: body, status: result.http_status
      end

      def render_application_deserializer_failure(deserialized)
        render_application_result(
          CommandTower::Workflows::WorkflowResult.failure(
            errors: [
              CommandTower::Errors::ValidationError.new(
                details: { failures: Array(deserialized.errors) }
              )
            ],
            http_status: :unprocessable_entity
          )
        )
      end

      def render_application_errors(errors:, status:, response_effects: nil)
        apply_response_effects(response_effects)
        render json: CommandTower::Serializers::Application::EnvelopeSerializer.failure(errors: errors),
               status: status
      end

      def apply_response_effects(effects)
        return if effects.blank?

        if effects[:set_token]
          CommandTower::Jwt::AuthorizationHelper.set_token(
            response,
            effects[:set_token][:token],
            expires_at: effects[:set_token][:expires_at]
          )
        end

        CommandTower::Jwt::AuthorizationHelper.clear_token(response) if effects[:clear_token]

        if effects[:clear_auth_cookie]
          CommandTower::Jwt::AuthorizationHelper.clear_cookie(response)
        end

        if effects[:ensure_csrf_cookie]
          CommandTower::Jwt::CsrfHelper.ensure_cookie(
            request,
            response,
            should_rotate: effects[:ensure_csrf_cookie][:rotate]
          )
        end

        return unless effects[:set_expire_header]

        response.set_header(
          CommandTower::Jwt::AuthorizationHelper::AUTHENTICATION_EXPIRE_HEADER,
          effects[:set_expire_header]
        )
      end
    end
  end
end
