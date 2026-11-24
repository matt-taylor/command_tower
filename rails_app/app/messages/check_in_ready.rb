# frozen_string_literal: true

# Sample definition with a check-in code. The inbox shows the code; the email composer also
# includes it, which is the violation that forces the fallback document. All values are fictional.
class CheckInReady < CommandTower::Messaging::MessageDefinition
  class Metadata < CommandTower::Messaging::MessageDefinition::Metadata
    attribute :class_name, :string
    attribute :code, :string
    attribute :headline, :string
    attribute :deep_link_path, :string

    validates :class_name, :code, presence: true
  end

  metadata_version 1
  metadata_schema Metadata
  default_zone "America/Los_Angeles"

  required_fact :class_name, :text

  fixture :default, metadata: {
    "class_name" => "Arms & Abs",
    "code" => "482913",
    "headline" => "Check in for Arms & Abs",
    "deep_link_path" => "/check-in"
  }

  def facts(builder, metadata:)
    builder.facts do |f|
      f.key_value { |rows| rows.item "Class", metadata["class_name"] }
    end
  end

  def inbox(builder, metadata:)
    builder.card(surface: :raised) do |c|
      c.text(metadata["headline"], variant: :heading_m)
      c.facts
      c.code(value: metadata["code"], label: "Check-in code", format: :text)
    end
  end

  # Includes the code on purpose; email must not carry it.
  def email(builder, metadata:)
    builder.card(surface: :raised) do |c|
      c.text(metadata["headline"], variant: :heading_m)
      c.facts
      c.code(value: metadata["code"], label: "Check-in code", format: :text)
    end
  end

  def slots(metadata:, **)
    {
      headline: metadata["headline"].presence || "Check in for #{metadata['class_name']}",
      subject: "Check in for #{metadata['class_name']}"
    }
  end
end
