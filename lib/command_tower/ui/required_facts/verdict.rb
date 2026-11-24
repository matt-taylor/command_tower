# frozen_string_literal: true

module CommandTower
  module UI
    module RequiredFacts
      # Pure check that rendered texts express a message's required facts. Runs in
      # specs and the gallery only, never on the send path.
      #
      #   Verdict.call(texts: { sms_body: "..." }, metadata:, required_facts:, render_zone:)
      #   # => [{ channel: :sms_body, fact_key: :starts_at, passed: true }]
      #
      # `texts` maps channel name to text. Callers leave out channels that must not
      # carry facts (`headline`, `pushover_title`). Each required fact is a Hash with
      # `key:`, `matcher:` (`:text`, `:time`, or a host matcher responding to
      # `call(text:, metadata:, t:)`), `zone:` (metadata key or `:user`) and `optional:`.
      # An optional fact whose metadata value is absent yields no rows.
      module Verdict
        def self.call(texts:, metadata:, required_facts:, render_zone:)
          t = translator(render_zone)

          required_facts.flat_map do |fact|
            key = fact.fetch(:key)
            next [] if fact[:optional] && fetch(metadata, key.to_s).nil?

            matcher = matcher_for(fact, render_zone)
            texts.map do |channel, text|
              { channel:, fact_key: key, passed: matcher.call(text:, metadata:, t:) == true }
            end
          end
        end

        def self.fetch(metadata, key)
          metadata.key?(key) ? metadata[key] : metadata[key.to_sym]
        end

        def self.translator(render_zone)
          lambda do |at, zone: render_zone, format: :short, label: :auto|
            TimeFormatter.call(at:, zone:, format:, label:, user_zone: render_zone)
          end
        end
        private_class_method :translator

        def self.matcher_for(fact, render_zone)
          case fact.fetch(:matcher)
          when :text then Matchers::Text.new(key: fact.fetch(:key))
          when :time then Matchers::Time.new(key: fact.fetch(:key), zone: fact[:zone], render_zone:)
          else fact.fetch(:matcher)
          end
        end
        private_class_method :matcher_for
      end
    end
  end
end
