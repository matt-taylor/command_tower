# frozen_string_literal: true

require "rspec/expectations"

# RSpec matchers shipped with CommandTower for host MessageDefinition specs.
#
#   require "command_tower/rspec/message_definition"
#
#   expect(ClassCanceled).to express_required_facts(fixture: :default)
#   expect(ClassCanceled).to have_fact_block_once
#   expect(CheckInReady).to exclude_code_from_email(fixture: :default)
#
# Each matcher renders the definition from one of its declared fixtures with the same pure code
# path the sender and the gallery use (`Definitions::DocumentBuilder`). `fixture:` defaults to the
# first declared fixture. Failure messages name channels, fact keys and node types, never values.
module CommandTower
  module Testing
    # Rendering helpers behind the matchers.
    module MessageDefinitionRendering
      # Slots that must not carry facts: the inbox headline and the Pushover title are labels.
      FACT_FREE_SLOTS = %i[headline pushover_title].freeze

      module_function

      def context_for(definition, fixture)
        metadata = metadata_for(definition, fixture)
        base = Messaging::Definitions::RenderContext.new(
          notification_type_key: "message_definition_spec",
          metadata:,
          metadata_version: definition.metadata_version,
          slots: nil,
          render_zone: definition.default_zone
        )
        base.with(slots: Messaging::Definitions::DocumentBuilder.slots(definition: definition.new, context: base))
      end

      def metadata_for(definition, fixture)
        name = (fixture || definition.fixtures.keys.first).to_s
        definition.fixtures.fetch(name) do
          raise ArgumentError, "#{definition.name} has no fixture #{name.inspect}"
        end
      end

      # @return [Hash{Symbol => String}] the channel slots that must express the required facts
      def fact_texts(definition, context)
        slots = Messaging::Definitions::DocumentBuilder.slots(definition: definition.new, context:)
        slots.except(*FACT_FREE_SLOTS).transform_values(&:to_s)
      end

      def document(definition, channel, context)
        Messaging::Definitions::DocumentBuilder.public_send(channel, definition: definition.new, context:)
      end

      # Every node `type` in the wire tree.
      def node_types(wire, found = [])
        case wire
        when Hash
          found << wire["type"] if wire["type"]
          wire.each_value { |value| node_types(value, found) }
        when Array
          wire.each { |value| node_types(value, found) }
        end
        found
      end
    end
  end
end

# Passes when every required fact is expressed in every fact-carrying channel text (subject, push,
# SMS, Pushover message). Fails naming the channel and fact key.
RSpec::Matchers.define :express_required_facts do |fixture: nil|
  match do |definition|
    helpers = CommandTower::Testing::MessageDefinitionRendering
    context = helpers.context_for(definition, fixture)
    verdicts = CommandTower::UI::RequiredFacts::Verdict.call(
      texts: helpers.fact_texts(definition, context),
      metadata: context.metadata,
      required_facts: definition.required_facts.map(&:to_h),
      render_zone: context.render_zone
    )
    @failures = verdicts.reject { |row| row[:passed] }
    @failures.empty?
  end

  failure_message do |definition|
    rows = @failures.map { |row| "#{row[:channel]} is missing #{row[:fact_key]}" }
    "expected #{definition.name} to express its required facts, but: #{rows.join('; ')}"
  end
end

# Passes when the inbox and email documents each contain exactly one `facts` node. Accepts a
# definition class (rendered from `fixture:`) or a built document.
RSpec::Matchers.define :have_fact_block_once do |fixture: nil|
  match do |subject|
    helpers = CommandTower::Testing::MessageDefinitionRendering
    @counts =
      if subject.is_a?(CommandTower::UI::Document)
        { document: helpers.node_types(subject.as_json["root"]).count("facts") }
      else
        context = helpers.context_for(subject, fixture)
        %i[inbox email].index_with do |channel|
          helpers.node_types(helpers.document(subject, channel, context).as_json["root"]).count("facts")
        end
      end
    @counts.values.all?(1)
  end

  failure_message do
    "expected exactly one facts node, found #{@counts.map { |name, count| "#{name}: #{count}" }.join(', ')}"
  end
end

# Passes when the email document carries no `code` node (check-in codes never go by email).
RSpec::Matchers.define :exclude_code_from_email do |fixture: nil|
  match do |definition|
    helpers = CommandTower::Testing::MessageDefinitionRendering
    context = helpers.context_for(definition, fixture)
    wire = helpers.document(definition, :email, context).as_json["root"]
    helpers.node_types(wire).exclude?("code")
  end

  failure_message do |definition|
    "expected the #{definition.name} email document to exclude a code node, but it contains one"
  end
end
