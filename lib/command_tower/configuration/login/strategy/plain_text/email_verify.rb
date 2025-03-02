    # frozen_string_literal: true

module CommandTower
  module Configuration
    module Login
      module Strategy
        module PlainText
          class EmailVerify < ::CommandTower::Configuration::Base
            include ClassComposer::Generator

            add_composer :enable,
              desc: "Email Verify will help ensure that users emails are valid by requesting a verify code. By default this is enabled",
              allowed: [FalseClass, TrueClass],
              default: true

            add_composer :verify_email_required_within,
              desc: "Strategy allows user to set time before email verification is required. After time has expired, usage of API is no longer valid until email has been verified. Up until this time, the Login Strategy will allow usage of the API. Default time is set to 0 minutes",
              allowed: ActiveSupport::Duration,
              default: 0.minutes,
              validator: -> (val) { val < 10.days },
              invalid_message: ->(val) { "Provided #{val}. Value must be less than #{10.days}" }


            add_composer :verify_code_link_required_within,
              desc: "When the email verification is sent, how long will that code be valid for. By default, this is set to 10 minutes",
              allowed: ActiveSupport::Duration,
              default: 10.minutes,
              validator: -> (val) { val < 60.minutes },
              invalid_message: ->(val) { "Provided #{val}. Value must be less than #{60.minutes}" }


            add_composer :verify_code_link_valid_for,
              desc: "When the email verification is sent, how long will that code be valid for. By default, this is set to 10 minutes",
              allowed: ActiveSupport::Duration,
              default: 10.minutes,
              validator: -> (val) { val < 60.minutes },
              invalid_message: ->(val) { "Provided #{val}. Value must be less than #{60.minutes}" }

            add_composer :verify_code_length,
              desc: "The length of the verify code sent via email.",
              allowed: Integer,
              default: 6,
              validator: -> (val) { (val <= 10) && (val >= 4) },
              invalid_message: ->(val) { "Provided #{val}. Value must be less than or equal to 10 and greater than or equal to 4." }
          end
        end
      end
    end
  end
end
