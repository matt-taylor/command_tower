# frozen_string_literal: true

module ApiEngineBase::Secrets
  ALLOWED_SECRET_REASONS = [
    EMAIL_VERIFICIATION = :email_verification,
    SSO = :sso,
  ]

  ALLOWED_SECRET_TYPES = [
    DEFAULT_SECRET_TYPE = ALPHANUMERIC = :alphanumeric,
    HEX = :hex,
    NUMERIC = :numeric,
    UUID = :uuid,
  ]
end
