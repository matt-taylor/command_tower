# frozen_string_literal: true

module CommandTower
  class EmailVerificationMailer < ApplicationMailer
    def verify_email(email, user, code)
      subject = "Welcome to #{}"
      @user = user
      @code = code
      mail(to: email, subject:)
    end
  end
end
