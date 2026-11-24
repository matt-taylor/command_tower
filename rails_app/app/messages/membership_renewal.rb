# frozen_string_literal: true

# Sample definition: inbox, email and push only (no SMS or Pushover), with times shown in the
# recipient's own zone. All values are fictional.
class MembershipRenewal < CommandTower::Messaging::MessageDefinition
  class Metadata < CommandTower::Messaging::MessageDefinition::Metadata
    attribute :plan_name, :string
    attribute :renews_at, :string
    attribute :headline, :string
    attribute :deep_link_path, :string

    validates :plan_name, :renews_at, presence: true
  end

  metadata_version 1
  metadata_schema Metadata
  default_zone "America/Los_Angeles"

  required_fact :plan_name, :text
  required_fact :renews_at, :time, zone: :user

  fixture :default, metadata: {
    "plan_name" => "Unlimited Monthly",
    "renews_at" => "2026-12-15T17:00:00Z",
    "headline" => "Your membership renews soon",
    "deep_link_path" => "/account/membership"
  }

  def facts(builder, metadata:)
    builder.facts do |f|
      f.key_value do |rows|
        rows.item "Plan", metadata["plan_name"]
        rows.item "Renews", rows.time(at: metadata["renews_at"], zone: :user, format: :short)
      end
    end
  end

  def slots(metadata:, t:, **) # rubocop:disable Naming/MethodParameterName -- `t:` is the formatter keyword
    when_text = t.call(metadata["renews_at"], zone: :user, format: :short)
    {
      headline: metadata["headline"].presence || "Your membership renews soon",
      subject: "Your #{metadata['plan_name']} membership renews #{when_text}",
      push_body: "#{metadata['plan_name']} renews #{when_text}."
    }
  end
end
