# frozen_string_literal: true

# Sample definition whose SMS deliberately leaves out `starts_at`, so the shipped
# `express_required_facts` helper fails for it. All values are fictional.
class ClassReminder < CommandTower::Messaging::MessageDefinition
  class Metadata < CommandTower::Messaging::MessageDefinition::Metadata
    attribute :class_name, :string
    attribute :starts_at, :string
    attribute :studio_zone, :string
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
    "class_name" => "Power Yoga",
    "starts_at" => "2026-12-06T18:00:00Z",
    "studio_zone" => "America/Los_Angeles",
    "headline" => "Power Yoga starts soon",
    "deep_link_path" => "/schedule"
  }

  def facts(builder, metadata:)
    builder.facts do |f|
      f.key_value do |rows|
        rows.item "Class", metadata["class_name"]
        rows.item "When", rows.time(at: metadata["starts_at"], zone: metadata["studio_zone"], format: :short)
      end
    end
  end

  def slots(metadata:, t:, **) # rubocop:disable Naming/MethodParameterName -- `t:` is the formatter keyword
    when_text = t.call(metadata["starts_at"], zone: metadata["studio_zone"], format: :short)
    {
      headline: metadata["headline"].presence || "#{metadata['class_name']} starts soon",
      subject: "Reminder: #{metadata['class_name']} at #{when_text}",
      # No start time here on purpose: this SMS fails `starts_at`.
      sms_body: "Reminder: #{metadata['class_name']} is coming up."
    }
  end
end
