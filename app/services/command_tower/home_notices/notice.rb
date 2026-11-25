# frozen_string_literal: true

module CommandTower
  module HomeNotices
    # Abstract base class for host-defined home notices. A notice declares its contract with class
    # macros and describes its behaviour with the overridable instance methods `show?` and `compose`.
    # Hosts subclass `Campaign` or `Delivery`, never `Notice` directly. Pacing, windows, selection and
    # audit are platform services; this class holds no state per user and its methods are pure.
    #
    #   class MakeYourPicks < CommandTower::HomeNotices::Campaign
    #     key        "pickem.make_your_picks"
    #     severity   :dismissible
    #     priority   50
    #     impressions max: 4, cooldown: 12.hours
    #   end
    class Notice
      SEVERITIES = %i[blocking dismissible].freeze
      Window = Data.define(:starts_at, :ends_at)

      class << self
        # Macro/reader. With an argument it sets, without it reads. Subclasses inherit.
        def key(value = nil)
          return inherited_setting(:@key) if value.nil?

          @key = value.to_s
        end

        def severity(value = nil)
          return inherited_setting(:@severity) if value.nil?

          unless SEVERITIES.include?(value)
            raise ArgumentError, "severity must be one of #{SEVERITIES.inspect} (got #{value.inspect})"
          end

          @severity = value
        end

        def priority(value = nil)
          return inherited_setting(:@priority) if value.nil?

          raise ArgumentError, "priority must be an Integer (got #{value.inspect})" unless value.is_a?(Integer)

          @priority = value
        end

        def blocking_reason(value = nil)
          return inherited_setting(:@blocking_reason) if value.nil?

          @blocking_reason = value.to_s
        end

        # Absolute UTC window. Either bound may be nil (open ended).
        def window(starts_at: nil, ends_at: nil)
          return inherited_setting(:@window) if starts_at.nil? && ends_at.nil?

          @window = Window.new(starts_at:, ends_at:)
        end

        def blocking?
          severity == :blocking
        end

        def dismissible?
          severity == :dismissible
        end

        private

        def inherited_setting(ivar)
          return instance_variable_get(ivar) if instance_variable_defined?(ivar)

          superclass.respond_to?(:key, true) ? superclass.send(:inherited_setting, ivar) : nil
        end
      end

      # Whether the notice applies to the user right now. No network I/O. `notice` is a read-only
      # NoticeRecord, or nil for an unmaterialized campaign.
      def show?(user:, context:, notice:) # rubocop:disable Lint/UnusedMethodArgument
        true
      end

      # Builds the notice content on the document builder.
      def compose(_builder, user:, context:, notice:) # rubocop:disable Lint/UnusedMethodArgument
        nil
      end
    end
  end
end
