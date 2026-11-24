# frozen_string_literal: true

module CommandTower
  module Messaging
    # Base class for host-defined messages. A definition declares its metadata contract with
    # class macros and describes its content with overridable instance methods. Registration
    # (`Declaration.build(..., message: Klass)`) lists the class; this class holds no state per
    # message and its methods are pure (no DB, no network).
    #
    #   class ClassCanceled < CommandTower::Messaging::MessageDefinition
    #     metadata_version 1
    #     metadata_schema  Metadata
    #     default_zone     "America/Los_Angeles"
    #     required_fact    :class_name, :text
    #     required_fact    :starts_at, :time, zone: "studio_zone"
    #     fixture :default, metadata: { "class_name" => "Arms & Abs", ... }
    #   end
    #
    # The `:basic` defaults for `facts`, `inbox`, `email`, `slots` and `headline` are the
    # behaviour a definition gets when it does not override a method. `inbox` and `email`
    # defaults ask the composer builder for its basic layout (`d.basic`).
    class MessageDefinition
      # One declared required fact. `matcher` is :text, :time or a host matcher class.
      # `zone` is a metadata key, :user, or nil.
      RequiredFact = Data.define(:key, :matcher, :zone, :optional)

      MATCHER_SYMBOLS = %i[text time].freeze

      class << self
        # Macro/reader. With an argument it sets, without it reads. Subclasses inherit.
        def metadata_version(value = nil)
          return inherited_setting(:@metadata_version) if value.nil?

          @metadata_version = value
        end

        def metadata_schema(klass = nil)
          return inherited_setting(:@metadata_schema) || Metadata if klass.nil?

          @metadata_schema = klass
        end

        def default_zone(zone = nil)
          return inherited_setting(:@default_zone) if zone.nil?

          @default_zone = zone.to_s
        end

        def promotional(value = nil)
          return inherited_setting(:@promotional) == true if value.nil?

          @promotional = value ? true : false
        end

        def promotional?
          promotional
        end

        def required_fact(key, matcher, zone: nil, optional: false)
          unless MATCHER_SYMBOLS.include?(matcher) || matcher.is_a?(Class)
            raise ArgumentError,
                  "required_fact matcher must be :text, :time or a matcher class (got #{matcher.inspect})"
          end

          fact = RequiredFact.new(key: key.to_s, matcher:, zone: normalize_zone(zone),
                                  optional: optional ? true : false)
          @required_facts = own_required_facts + [fact]
        end

        # @return [Array<RequiredFact>] inherited facts first, then this class's own
        def required_facts
          inherited = superclass.respond_to?(:required_facts) ? superclass.required_facts : []
          (inherited + own_required_facts).freeze
        end

        def fixture(name, metadata:)
          @fixtures = own_fixtures.merge(name.to_s => deep_freeze(metadata.to_h.transform_keys(&:to_s)))
        end

        # @return [Hash{String => Hash}] fixture name => string-keyed metadata, declaration order
        def fixtures
          inherited = superclass.respond_to?(:fixtures) ? superclass.fixtures : {}
          inherited.merge(own_fixtures).freeze
        end

        private

        def inherited_setting(ivar)
          return instance_variable_get(ivar) if instance_variable_defined?(ivar)

          superclass.respond_to?(:metadata_version, true) ? superclass.send(:inherited_setting, ivar) : nil
        end

        def normalize_zone(zone)
          return nil if zone.nil?

          zone == :user ? :user : zone.to_s
        end

        def own_required_facts
          @required_facts || []
        end

        def own_fixtures
          @fixtures || {}
        end

        def deep_freeze(value)
          case value
          when Hash then value.each_value { |v| deep_freeze(v) }
          when Array then value.each { |v| deep_freeze(v) }
          end
          value.freeze
        end
      end

      # Fact block shared by every channel's document. Default: no fact block.
      def facts(_factory, **)
        nil
      end

      def inbox(builder, **)
        builder.basic
      end

      def email(builder, **)
        builder.basic
      end

      # Headline slot. Default reads the metadata `headline` key.
      def headline(metadata:)
        metadata["headline"]
      end

      # Channel slots as a Hash keyed by slot name (headline, subject, push_body, sms_body,
      # pushover_title, pushover_message). Overrides also receive `t:`, the zone-aware time
      # formatter callable.
      def slots(metadata:, **)
        { headline: headline(metadata:) }
      end
    end
  end
end
