# frozen_string_literal: true

# Dummy-app mailer that wraps a rendered UI document email (html + text parts)
# so UiDocumentPreview can show it at /rails/mailers/ui_document/<fixture>.
class UiDocumentMailer < ApplicationMailer
  layout false

  def document_email(html:, text:, subject:)
    mail(to: "preview@example.com", subject:) do |format|
      format.text { render plain: text }
      format.html { render html: html.html_safe } # rubocop:disable Rails/OutputSafety
    end
  end
end
