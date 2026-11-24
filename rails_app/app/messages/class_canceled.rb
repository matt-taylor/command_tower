# frozen_string_literal: true

# Sample definition for the rails_app host: every channel, rendered in the studio's zone.
# All values are fictional.
class ClassCanceled < CommandTower::Messaging::MessageDefinition
  class Metadata < CommandTower::Messaging::MessageDefinition::Metadata
    attribute :class_name, :string
    attribute :starts_at, :string
    attribute :studio_zone, :string
    attribute :location, :string
    attribute :headline, :string
    attribute :deep_link_path, :string

    validates :class_name, :starts_at, :studio_zone, presence: true
  end

  metadata_version 1
  metadata_schema Metadata
  default_zone "America/Los_Angeles"

  required_fact :class_name, :text
  required_fact :starts_at, :time, zone: "studio_zone"

  fixture :default, metadata: {
    "class_name" => "Arms & Abs",
    "starts_at" => "2026-12-04T14:00:00Z",
    "studio_zone" => "America/Los_Angeles",
    "location" => "Studio B",
    "headline" => "Arms & Abs is canceled",
    "deep_link_path" => "/schedule"
  }

  fixture :other_zone, metadata: {
    "class_name" => "Sunrise Stretch",
    "starts_at" => "2026-12-05T15:30:00Z",
    "studio_zone" => "America/New_York",
    "location" => "Studio A",
    "headline" => "Sunrise Stretch is canceled",
    "deep_link_path" => "/schedule"
  }

  def facts(builder, metadata:)
    builder.facts do |f|
      f.key_value do |rows|
        rows.item "Class", metadata["class_name"]
        rows.item "When", rows.time(at: metadata["starts_at"], zone: metadata["studio_zone"], format: :short)
        rows.item "Where", metadata["location"] if metadata["location"].present?
      end
    end
  end

  def slots(metadata:, t:, **) # rubocop:disable Naming/MethodParameterName -- `t:` is the formatter keyword
    name = metadata["class_name"]
    when_text = t.call(metadata["starts_at"], zone: metadata["studio_zone"], format: :short)
    {
      headline: metadata["headline"].presence || "#{name} is canceled",
      subject: "#{name} is canceled, #{when_text}",
      push_body: "#{name} on #{when_text} is canceled.",
      sms_body: "#{name} on #{when_text} is canceled.",
      pushover_title: "Class canceled",
      pushover_message: "#{name} on #{when_text} is canceled."
    }
  end
end
