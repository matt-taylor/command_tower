# frozen_string_literal: true

module CommandTower
  module HomeNotices
    class Catalog
      # Per-class boot checks (design D2). Returns the list of problems for one notice class.
      module Validator
        KEY_FORMAT = /\A[a-z0-9_]+(\.[a-z0-9_]+)+\z/
        RESERVED_KEY_PREFIX = "ct."
        MIN_BLOCKING_REASON_LENGTH = 20

        module_function

        # `builtin` is true for platform notices, which may use the reserved key prefix.
        def errors_for(klass, builtin: false)
          return ["must subclass CommandTower::HomeNotices::Campaign or Delivery"] unless notice_subclass?(klass)

          key_errors(klass, builtin:) + severity_errors(klass) + kind_errors(klass) +
            show_errors(klass) + compose_errors(klass) + window_errors(klass)
        end

        def notice_subclass?(klass)
          klass.is_a?(Class) && (klass < Campaign || klass < Delivery)
        end

        def key_errors(klass, builtin: false)
          key = klass.key
          return ["key is required"] if key.nil?
          return ["key #{key.inspect} must match #{KEY_FORMAT.inspect}"] unless KEY_FORMAT.match?(key)
          return [] if builtin || !key.start_with?(RESERVED_KEY_PREFIX)

          ["key #{key.inspect} uses the reserved #{RESERVED_KEY_PREFIX} prefix"]
        end

        def severity_errors(klass)
          errors = []
          errors << "severity is required" if klass.severity.nil?
          errors << "priority is required" if klass.priority.nil?
          if klass.blocking? && klass.blocking_reason.to_s.length < MIN_BLOCKING_REASON_LENGTH
            errors << "a blocking notice needs blocking_reason of at least #{MIN_BLOCKING_REASON_LENGTH} characters"
          end
          errors
        end

        # Macros are defined on one kind only, so a notice of the other kind must not carry them.
        def kind_errors(klass)
          klass < Campaign ? campaign_errors(klass) : delivery_errors(klass)
        end

        def campaign_errors(klass)
          errors = []
          errors << "composer is a Delivery macro" if klass.respond_to?(:composer)
          errors << "a dismissible campaign must declare impressions" if klass.dismissible? && klass.impressions.nil?
          errors
        end

        def delivery_errors(klass)
          return [] unless klass.respond_to?(:impressions) || klass.respond_to?(:period_key)

          ["impressions and period_key are Campaign macros"]
        end

        # The owner of `show?` must not be `Notice`. An unlinked Delivery must not rely on `Delivery`
        # either; the linked default (`composer :message`) counts as an override.
        def show_errors(klass)
          owner = klass.instance_method(:show?).owner
          inherited = owner == Notice || (klass < Delivery && !linked_delivery?(klass) && owner == Delivery)
          inherited ? ["show? must be overridden"] : []
        end

        def compose_errors(klass)
          return [] if linked_delivery?(klass)
          return [] unless klass.instance_method(:compose).owner == Notice

          ["compose must be overridden"]
        end

        def window_errors(klass)
          window = klass.window
          return [] if window.nil? || window.starts_at.nil? || window.ends_at.nil?
          return [] if window.starts_at < window.ends_at

          ["window starts_at must be before ends_at"]
        end

        def linked_delivery?(klass)
          klass < Delivery && klass.composer == :message
        end
      end
    end
  end
end
