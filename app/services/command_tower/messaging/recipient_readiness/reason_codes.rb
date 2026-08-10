# frozen_string_literal: true

module CommandTower
  module Messaging
    module RecipientReadiness
      module ReasonCodes
        PLATFORM_DISABLED = "platform_disabled"
        PLATFORM_UNCONFIGURED = "platform_unconfigured"
        IDENTITY_MISSING = "identity_missing"
        IDENTITY_UNAVAILABLE = "identity_unavailable"
        IDENTITY_UNVERIFIED = "identity_unverified"
        ENDPOINT_MISSING = "endpoint_missing"
        ENDPOINT_INACTIVE = "endpoint_inactive"
        ENDPOINT_UNVERIFIED = "endpoint_unverified"
        ENDPOINT_INVALID = "endpoint_invalid"
        CREDENTIALS_MISSING = "credentials_missing"

        ALL = [
          PLATFORM_DISABLED,
          PLATFORM_UNCONFIGURED,
          IDENTITY_MISSING,
          IDENTITY_UNAVAILABLE,
          IDENTITY_UNVERIFIED,
          ENDPOINT_MISSING,
          ENDPOINT_INACTIVE,
          ENDPOINT_UNVERIFIED,
          ENDPOINT_INVALID,
          CREDENTIALS_MISSING,
        ].freeze
      end
    end
  end
end
