# frozen_string_literal: true

module CommandTower
  module Audit
    module Attribution
      MODES = %i[self_service admin_direct impersonation system].freeze

      module_function

      def resolve(affected_user_id:, attribution_mode:)
        requested = normalize_mode(attribution_mode)
        impersonating = CommandTower::Current.impersonation_active == true

        if impersonating
          if requested && requested != :impersonation
            raise InvalidAttributionError,
              "attribution_mode #{requested} conflicts with active impersonation"
          end

          originating = CommandTower::Current.originating_administrator_id
          if originating.nil?
            raise InvalidAttributionError, "impersonation requires originating_administrator_id"
          end

          return envelope(
            mode: :impersonation,
            actor_user_id: originating,
            affected_user_id:
          )
        end

        if requested == :impersonation
          raise InvalidAttributionError, "attribution_mode impersonation requires impersonation_active"
        end

        if requested == :system || (requested.nil? && CommandTower::Current.user_id.nil?)
          return envelope(mode: :system, actor_user_id: nil, affected_user_id:)
        end

        if requested == :admin_direct
          if CommandTower::Current.user_id.nil?
            raise InvalidAttributionError, "admin_direct requires a Current.user_id actor"
          end

          return envelope(mode: :admin_direct, actor_user_id: CommandTower::Current.user_id, affected_user_id:)
        end

        actor_id = CommandTower::Current.user_id
        if actor_id.nil?
          raise InvalidAttributionError, "self_service requires a Current.user_id actor"
        end

        if requested.nil? && !affected_user_id.nil? && actor_id != affected_user_id
          raise InvalidAttributionError,
            "attribution_mode must be explicit when actor and affected user differ"
        end

        if requested == :self_service && !affected_user_id.nil? && actor_id != affected_user_id
          raise InvalidAttributionError,
            "self_service requires Current.user_id to match affected_user_id"
        end

        envelope(mode: :self_service, actor_user_id: actor_id, affected_user_id:)
      end

      def normalize_mode(value)
        return nil if value.nil?

        mode = value.to_sym
        unless MODES.include?(mode)
          raise InvalidAttributionError, "invalid attribution_mode #{value.inspect}"
        end

        mode
      end

      def envelope(mode:, actor_user_id:, affected_user_id:)
        {
          attribution_mode: mode,
          actor_user_id:,
          affected_user_id:,
          effective_user_id: CommandTower::Current.effective_user_id || CommandTower::Current.user_id,
          originating_administrator_id: CommandTower::Current.originating_administrator_id,
          impersonation_active: CommandTower::Current.impersonation_active == true,
          user_id: CommandTower::Current.user_id
        }
      end
    end
  end
end
