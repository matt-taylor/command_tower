# frozen_string_literal: true

module CommandTower
  module Configuration
    module Login
      module Strategy
        module PlainText
          class Locakable < ::CommandTower::Configuration::Base
            include ClassComposer::Generator

            add_composer :enable,
              desc: "Disabled by default. When enabled, this adds an additional level of support for brute force attacks on User/Password Logins",
              allowed: [FalseClass, TrueClass],
              default: false

            add_composer :password_attempts,
              desc: "Max failed password attempts before additional verification on account is required.",
              allowed: Integer,
              default: 10,
              validator: -> (val) { val >= 0 && val < 50 },
              invalid_message: ->(val) { "Max password attempts must be >=0 and less than 50. Received #{val}" }
          end
        end
      end
    end
  end
end
