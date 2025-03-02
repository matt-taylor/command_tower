# frozen_string_literal: true

module CommandTower::LoginStrategy::PlainText
  class Create < CommandTower::ServiceBase
    on_argument_validation :fail_early

    EASY_GETTER = CommandTower.config.login.plain_text

    validate :first_name, is_a: String, required: true
    validate :last_name, is_a: String, required: true
    validate :username, is_a: String, required: true
    validate :email, length: true, lt: EASY_GETTER.email_length_max, gt: EASY_GETTER.email_length_min, is_a: String, required: true, sensitive: true
    validate :password, length: true, lt: EASY_GETTER.password_length_max, gt: EASY_GETTER.password_length_min, is_a: String, required: true, sensitive: true
    validate :password_confirmation, is_a: String, required: true, sensitive: true

    def call
      unless email =~ URI::MailTo::EMAIL_REGEXP
        inline_argument_failure!(errors: { email: "Invalid email address" })
      end

      username_validity = CommandTower::Username::Available.(username:)
      if !username_validity.valid
        inline_argument_failure!(errors: { username: "Username is invalid. #{CommandTower.config.username.username_failure_message}" })
      end

      user = User.new(
        first_name:,
        last_name:,
        username:,
        email:,
        password:,
        password_confirmation:,
      )

      if user.save
        context.user = user
        CommandTower::InboxService::Blast::NewUserBlaster.(user:)
      else
        inline_argument_failure!(errors: user.errors)
      end
    end
  end
end
