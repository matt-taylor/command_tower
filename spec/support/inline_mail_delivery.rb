# frozen_string_literal: true

# Runs auth mail synchronously (config.login.mail_delivery = :inline) so specs can
# observe delivery and delivery failures. Default is :later (enqueue).
RSpec.shared_context "with inline mail delivery" do
  around do |example|
    CommandTower.configure { |config| config.login.mail_delivery = :inline }
    example.run
  ensure
    CommandTower.configure { |config| config.login.mail_delivery = :later }
  end
end
