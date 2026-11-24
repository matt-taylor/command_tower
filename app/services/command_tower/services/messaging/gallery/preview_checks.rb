# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Gallery
        # The gallery's pass/fail checks for one rendered preview. Rows name checks, channels and
        # fact keys only, never metadata values, slot text or code values.
        #
        # - `required_fact`: every required fact appears in each fact-carrying slot and in the fact
        #   block's derived text (`UI::RequiredFacts::Verdict`).
        # - `fact_block_once`: each rendered document has exactly one `facts` node.
        # - `no_code_in_slots_or_body`: no `code` node in the email document, and no code value in
        #   any slot, push, SMS, Pushover or email text.
        # - `no_time_in_headline`: the headline carries none of the required `:time` facts.
        module PreviewChecks
          FACT_FREE_SLOTS = %i[headline pushover_title].freeze

          module_function

          # @param definition [Class] the MessageDefinition subclass
          # @param context [Messaging::Definitions::RenderContext] with slots resolved
          # @param documents [Hash] wire hashes keyed `:inbox`, `:email`, `:facts` (nil when absent)
          # @param texts [Array<String>] every rendered text the code values must stay out of
          # @param fact_text [String] derived text of the fact block ("" when there is none)
          # @return [Array<Hash>]
          def call(definition:, context:, documents:, texts:, fact_text:)
            required_fact_rows(definition, context, fact_text) +
              fact_block_rows(documents) +
              [no_code_row(documents, texts), no_time_in_headline_row(definition, context)]
          end

          def required_fact_rows(definition, context, fact_text)
            candidates = context.slots.except(*FACT_FREE_SLOTS).transform_values(&:to_s)
            candidates = candidates.merge(fact_block: fact_text) if fact_text.present?
            verdicts(definition, context, candidates).map do |row|
              { check: "required_fact", channel: row[:channel].to_s, fact_key: row[:fact_key].to_s,
                passed: row[:passed] }
            end
          end

          def fact_block_rows(documents)
            documents.slice(:inbox, :email).filter_map do |channel, wire|
              next if wire.nil?

              { check: "fact_block_once", channel: channel.to_s, passed: node_values(wire, "facts").size == 1 }
            end
          end

          def no_code_row(documents, texts)
            email = documents[:email]
            code_values = documents.values.compact.flat_map { |wire| node_values(wire, "code", "value") }
            leaked = code_values.any? { |value| texts.any? { |text| text.include?(value.to_s) } }
            email_has_code = email ? node_values(email, "code").any? : false
            { check: "no_code_in_slots_or_body", passed: !leaked && !email_has_code }
          end

          def no_time_in_headline_row(definition, context)
            time_facts = definition.required_facts.select { |fact| fact.matcher == :time }.map(&:to_h)
            rows = verdicts(definition, context, { headline: context.slots[:headline].to_s }, time_facts)
            { check: "no_time_in_headline", passed: rows.none? { |row| row[:passed] } }
          end

          def verdicts(definition, context, texts, facts = definition.required_facts.map(&:to_h))
            CommandTower::UI::RequiredFacts::Verdict.call(
              texts:, metadata: context.metadata, required_facts: facts, render_zone: context.render_zone
            )
          end

          # Values of nodes of `type` in a wire tree: the node's `field`, or the node itself.
          def node_values(wire, type, field = nil, found = [])
            case wire
            when Hash
              found << (field ? wire[field] : wire) if wire["type"] == type
              wire.each_value { |value| node_values(value, type, field, found) }
            when Array
              wire.each { |value| node_values(value, type, field, found) }
            end
            found
          end
        end
      end
    end
  end
end
