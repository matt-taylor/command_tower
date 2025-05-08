require "command_tower"

=begin
This configuration files lists all the configuration options available.
To change the default value, uncomment the line and change the value.
Please take note: Values set as `=` to a config variable are the current default values when none is assigned
=end

CommandTower.configure do |config|
  # Remove Secret after it is found as invalid: [TrueClass, FalseClass]
  # config.delete_secret_after_invalid = true

  # #########################
  # #                       #
  # #########  Jwt  #########
  # #                       #
  # #########################
  # ## JWT is the basis for Authorization and Authentication for this Engine. HMAC is the only support algorithm

  # Default TTL on how long the token is valid for: [ActiveSupport::Duration]
  # config.jwt.ttl = 7.days

  # HMAC is the only algorithm supported. This is the secret key to encrypt he JWT token: [String]
  # config.jwt.hmac_secret = ENV.fetch("SECRET_KEY_BASE","Thi$IsASeccretIwi::CH&ang3")

  # ###########################
  # #                         #
  # #########  Login  #########
  # #                         #
  # ###########################
  # ## Definition of Login Strategies.

  # ### Block to configure Plain Text ###
  # Login strategy for plain text authentication via User/Password combination
  # When using the block, the enable flag will automatically get set to true
  # config.login.with_plain_text do |plain_text_config|
    # Login Strategy for User/Password. By default, this is enabled: [FalseClass, TrueClass]
    # plain_text_config.enable = true

    # ### Block to configure Lockable ###
    # Enable and change Lockable for User/Password Login strategy.
    # When using the block, the enable flag will automatically get set to true
    # plain_text_config.with_lockable do |lockable_config|
      # Disabled by default. When enabled, this adds an additional level of support for brute force attacks on User/Password Logins: [FalseClass, TrueClass]
      # lockable_config.enable = false

      # Max failed password attempts before additional verification on account is required.: [Integer]
      # lockable_config.password_attempts = 10
    # end

    # ### Block to configure Email Verify ###
    # Enable and change Email Verification for User/Password Login strategy.
    # When using the block, the enable flag will automatically get set to true
    # plain_text_config.with_email_verify do |email_verify_config|
      # Email Verify will help ensure that users emails are valid by requesting a verify code. By default this is enabled: [FalseClass, TrueClass]
      # email_verify_config.enable = true

      # Strategy allows user to set time before email verification is required. After time has expired, usage of API is no longer valid until email has been verified. Up until this time, the Login Strategy will allow usage of the API. Default time is set to 0 minutes: [ActiveSupport::Duration]
      # email_verify_config.verify_email_required_within = 0.minutes

      # When the email verification is sent, how long will that code be valid for. By default, this is set to 10 minutes: [ActiveSupport::Duration]
      # email_verify_config.verify_code_link_required_within = 10.minutes

      # When the email verification is sent, how long will that code be valid for. By default, this is set to 10 minutes: [ActiveSupport::Duration]
      # email_verify_config.verify_code_link_valid_for = 10.minutes

      # The length of the verify code sent via email.: [Integer]
      # email_verify_config.verify_code_length = 6
    # end

    # Max Length for Password: [Integer]
    # plain_text_config.password_length_max = 64

    # Min Length for Password: [Integer]
    # plain_text_config.password_length_min = 8

    # Max Length for Email: [Integer]
    # plain_text_config.email_length_max = 64

    # Min Length for Email: [Integer]
    # plain_text_config.email_length_min = 8
  # end

  # ###########################
  # #                         #
  # #########  Email  #########
  # #                         #
  # ###########################
  # ## Email configuration for the app sending Native Rails emails via ActiveMailer. Config changed here will update the Rails Configuration as well

  # User Name for email. Defaults to ENV['GMAIL_USER_NAME']: [String]
  # config.email.user_name = ENV["GMAIL_USER_NAME"]

  # Password for email. Defaults to ENV['GMAIL_PASSWORD']. For more info on how to get this for GMAIL...https://support.google.com/accounts/answer/185833: [String]
  # config.email.password = ENV["GMAIL_PASSWORD"]

  # config.email.port = 587

  # SMTP address for email. Defaults to smtp.gmail.com: [String]
  # config.email.address = "smtp.gmail.com"

  # Authentication type for email: [String]
  # config.email.authentication = "plain"

  # config.email.enable_starttls_auto = true

  # config.email.delivery_method = :smtp

  # config.email.perform_deliveries = true

  # config.email.raise_delivery_errors = true

  # ##############################
  # #                            #
  # #########  Username  #########
  # #                            #
  # ##############################
  # ## Username configuration for the app

  # ### Block to configure Realtime Username Check ###
  # Adds components to check if the username is available in real time
  # When using the block, the enable flag will automatically get set to true
  # config.username.with_realtime_username_check do |realtime_username_check_config|
    # Enable Controller method for checking Real time username availability: [FalseClass, TrueClass]
    # realtime_username_check_config.enable = true

    # Local Cache store. Instantiated before fork: [ActiveSupport::Cache::MemoryStore, ActiveSupport::Cache::FileStore]
    # realtime_username_check_config.local_cache = ActiveSupport::Cache::MemoryStore

    # TTL on local cache data before data is invalidated and upstream is queried: [ActiveSupport::Duration]
    # realtime_username_check_config.local_cache_ttl = 1.minutes
  # end

  # Min Length for Username: [Integer]
  # config.username.username_length_min = 4

  # Max Length for Username: [Integer]
  # config.username.username_length_max = 32

  # Regex for username.: [Regexp]
  # config.username.username_regex = Regexp.new("/Aw{4,32}z/")

  # Max Length for Username: [String]
  # config.username.username_failure_message = "Username length must be between 4 and 32. Must contain only letters and/or numbers"

  # #################################
  # #                               #
  # #########  Application  #########
  # #                               #
  # #################################
  # ## General configurations for the application. Primarily include application specific names, URL's, etc

  # The default name of the application: [String]
  # config.application.app_name = # Auto Populates to the name of the application

  # The name of the application to use in communications like SMS or Email: [String]
  # config.application.communication_name = config.application.app_name

  # When composing SSO's or verification URL's, this is the URL for the application: [String]
  # config.application.url = "http://localhost"

  # When composing SSO's or verification URL's, this is the PORT for the application: [String, NilClass]
  # config.application.port = "7777"

  # The fully composed URL including the port number when needed. This Config variable is not needed as it is composed of the `url` and `port` composed values: [String]
  # config.application.composed_url = # Composed String of the URL and PORT. Override this with caution

  # ###################################
  # #                                 #
  # #########  Authorization  #########
  # #                                 #
  # ###################################
  # ## Authorization via rbac configurations

  # The default Group Roles defined by this engine.: [TrueClass, FalseClass]
  # config.authorization.rbac_default_groups = true

  # If defined, this config points to the users YAML file defining RBAC group roles.: [String]
  # config.authorization.rbac_group_path = Rails.root.join("config","rbac_groups.yml")

  # ##########################
  # #                        #
  # #########  User  #########
  # #                        #
  # ##########################
  # ## User configuration for the app. Includes what to display and what attributes can be changed

  # On top of the default attributes to change, this adds additional values for the user to change on their account: [Array]
  # config.user.additional_attributes_for_change = []

  # [Not Recommended for change] Default attributes that are allowed to change: [Array]
  # config.user.default_attributes_for_change = email first_name last_name last_known_timezone username verifier_token

  # [Not Recommended for change] Default attributes that are shown to the user: [Array]
  # config.user.default_attributes = email first_name last_name last_known_timezone username verifier_token id roles created_at

  # ###########################
  # #                         #
  # #########  Admin  #########
  # #                         #
  # ###########################
  # ## Admin configuration for the app

  # Allow Admin Capabilities for the application. By default, this is enabled: [FalseClass, TrueClass]
  # config.admin.enable = true

  # ################################
  # #                              #
  # #########  Pagination  #########
  # #                              #
  # ################################
  # ## Pagination configuration for the app

  # Default Limit for pagination return when not present on service or query/body. Negative values are treated like no limit: [Integer]
  # config.pagination.limit = 10

  # #########################
  # #                       #
  # #########  Otp  #########
  # #                       #
  # #########################
  # ## One Time Password generation is used for ease in quickly validating a users actions. This is good for short term validation requirements as opposed to UserSecrets

  # The length of time a code is good for: [ActiveSupport::Duration]
  # config.otp.default_code_interval = 30.seconds

  # The default length of the OTP. Used when one not provided: [Integer]
  # config.otp.default_code_length = 6

  # The size of each users base32 Secret value generated: [Integer]
  # config.otp.secret_code_length = 32

  # The length of each backup code for User: [Integer]
  # config.otp.backup_code_length = 32

  # The number of backup codes that get generated: [Integer]
  # config.otp.backup_code_count = 10

  # Sometimes a user is just a tad slow. This allows a small drift behind to allow codes within drift to be accepted: [ActiveSupport::Duration]
  # config.otp.allowed_drift_behind = 15.seconds
end