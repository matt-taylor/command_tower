# frozen_string_literal: true

module CommandTower
  class EmailVerificationMailer < ApplicationMailer
    def verify_email(email, user, code, template_name: nil)
      subject = "Welcome to #{CommandTower.config.app.communication_name }"
      @user = user
      @code = code

      template = template_name || "verify_email"
      mail(to: email, subject:, template_name: template)
    end
  end
end
