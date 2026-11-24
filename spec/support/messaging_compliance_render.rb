# frozen_string_literal: true

# Helpers for the compliance footer and one-click header render specs. Expects the including group
# to provide `origin` (MessagingDefinedRenderHelper) and `preferences_path`.
module MessagingComplianceRenderHelper
  FOOTER_SENTENCE = "You&#39;re getting this email because Class canceled emails are turned on for your"

  def compliance
    CommandTower.config.messaging.compliance
  end

  def postal_address
    "1 Main Street, Springfield"
  end

  def footer_origin
    "#{origin}#{preferences_path}"
  end

  def payload
    @payload ||= render_channel("email", "recipient@example.com")
  end

  def header_url
    payload.headers.fetch("List-Unsubscribe")[/\A<(.+)>\z/, 1]
  end

  def header_token
    Rack::Utils.parse_query(URI(header_url).query).fetch("token")
  end
end

RSpec.configure do |config|
  config.include MessagingComplianceRenderHelper, :compliance_render
end
