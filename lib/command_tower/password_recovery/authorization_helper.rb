# frozen_string_literal: true

module CommandTower
  module PasswordRecovery
    module AuthorizationHelper
      SCHEME = "Recovery"
      HEADER = "Authorization"

      module_function

      def extract_token(request)
        raw = request.headers[HEADER].to_s.strip
        return { error: :missing } if raw.blank?

        match = raw.match(/\A#{SCHEME}\s+(.+)\z/i)
        return { error: :invalid_format } unless match

        token = match[1].to_s.strip
        return { error: :missing } if token.blank?

        { token: token }
      end
    end
  end
end
