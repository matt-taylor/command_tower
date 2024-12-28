# frozen_string_literal: true

module ApiEngineBase
  class ApplicationMailer < ActionMailer::Base
    default from: "from@example.com"
    layout "mailer"
  end
end
