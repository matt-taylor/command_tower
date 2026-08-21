# frozen_string_literal: true

module CommandTower
  class ApplicationMailer < ActionMailer::Base
    FALLBACK_FROM = "from@example.com"

    default from: -> { smtp_from_address }
    layout "mailer"

    def self.smtp_from_address
      CredentialResolution.resolve(:smtp).user_name.presence || FALLBACK_FROM
    end

    def smtp_from_address
      self.class.smtp_from_address
    end
  end
end
