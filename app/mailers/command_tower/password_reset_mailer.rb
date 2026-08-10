# frozen_string_literal: true

module CommandTower
  class PasswordResetMailer < ApplicationMailer
    def reset_password(email, user, token, template_name: nil)
      subject = "Reset Your Password for #{CommandTower.config.app.communication_name}"
      @user = user
      @token = token
      @email = email
      password_reset_config = CommandTower.config.login.plain_text.password_reset
      @require_email = password_reset_config.require_email
      @reset_password_path = password_reset_config.reset_password_path

      template = template_name || password_reset_config.custom_template_name || "reset_password"
      mail(to: email, subject:, template_name: template)
    end
  end
end
