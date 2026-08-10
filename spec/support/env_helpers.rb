# frozen_string_literal: true

module EnvHelpers
  module_function

  def with_env(overrides)
    previous = overrides.keys.index_with { |key| ENV[key] }
    overrides.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end

module CredentialResolutionHelpers
  module_function

  def reset_credentials!
    CommandTower.config.credentials.twilio.account_sid = ""
    CommandTower.config.credentials.twilio.auth_token = ""
    CommandTower.config.credentials.smtp.user_name = ""
    CommandTower.config.credentials.smtp.password = ""
    CommandTower.credential_resolver = nil
  end
end

RSpec.configure do |config|
  config.include EnvHelpers, file_path: %r{credential_resolution_spec\.rb$}
  config.include CredentialResolutionHelpers, file_path: %r{credential_resolution_spec\.rb$}
  config.include EnvHelpers, file_path: %r{sms/configuration_spec\.rb$}
  config.include EnvHelpers, file_path: %r{phone_verification/sms_configuration_spec\.rb$}
end
