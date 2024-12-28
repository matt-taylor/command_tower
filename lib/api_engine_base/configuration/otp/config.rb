# frozen_string_literal: true

require "class_composer"

module ApiEngineBase
  module Configuration
    module Otp
      class Config
        include ClassComposer::Generator

        add_composer :default_code_interval,
          desc: "The length of time a code is good for",
          allowed: ActiveSupport::Duration,
          default: 30.seconds,
          validator: -> (val) { (val <= 5.minutes) && (val >= 30.seconds) }

        add_composer :default_code_length,
          desc: "The default length of the OTP. Used when one not provided",
          allowed: Integer,
          default: 6,
          validator: -> (val) { (val <= 10) && (val >= 4) },
          invalid_message: ->(val) { "Provided #{val}. Value must be less than or equal to 10 and greater than or equal to 4." }

        add_composer :secret_code_length,
          desc: "The size of each users base32 Secret value generated",
          allowed: Integer,
          default: 32,
          validator: -> (val) { (val <= 128) && (val >= 32) },
          invalid_message: ->(val) { "Provided #{val}. Value must be less than or equal to 128 and greater than or equal to 32." }

        add_composer :backup_code_length,
          desc: "The length of each backup code for User",
          allowed: Integer,
          default: 32,
          validator: -> (val) { (val <= 64) && (val >= 10) },
          invalid_message: ->(val) { "Provided #{val}. Value must be less than or equal to 64 and greater than or equal to 20." }

        add_composer :backup_code_count,
          desc: "The number of backup codes that get generated",
          allowed: Integer,
          default: 10,
          validator: -> (val) { (val <= 10) && (val >= 2) },
          invalid_message: ->(val) { "Provided #{val}. Value must be less than or equal to 10 and greater than or equal to 2." }

        add_composer :allowed_drift_behind,
          desc: "Sometimes a user is just a tad slow. This allows a small drift behind to allow codes within drift to be accepted",
          allowed: ActiveSupport::Duration,
          default: 15.seconds,
          validator: -> (val) { (val <= 15.seconds) && (val >= 0.seconds) },
          invalid_message: ->(val) { "Provided #{val}. Value must be less than or equal to 15.seconds" }
      end
    end
  end
end
