# frozen_string_literal: true

module CommandTower::Secrets
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
