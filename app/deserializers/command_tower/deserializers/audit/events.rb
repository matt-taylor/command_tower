# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Audit
      module Events
        class UserListDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:limit, :offset, :actions, :occurred_after, :occurred_before, :subject_types)
          DEFAULT_LIMIT = 50
          MAX_LIMIT = 100
          MAX_MULTI = 50
          EVENT_NAME = /\A[a-z][a-z0-9_]*\z/
          SUBJECT_TYPE = /\A[A-Z][A-Za-z0-9_:]*\z/

          def call(params)
            limit = pagination_integer(fetch_param(params, :limit).value, default: DEFAULT_LIMIT, minimum: 1, maximum: MAX_LIMIT)
            return failure(errors: { message: "invalid_limit" }) if limit.nil?

            offset = pagination_integer(fetch_param(params, :offset).value, default: 0, minimum: 0)
            return failure(errors: { message: "invalid_offset" }) if offset.nil?

            actions = optional_event_names(params)
            return actions if deserializer_result?(actions)

            occurred_after = optional_time(fetch_param(params, :occurredAfter, :occurred_after).value, field: "occurredAfter")
            return occurred_after if deserializer_result?(occurred_after)

            occurred_before = optional_time(fetch_param(params, :occurredBefore, :occurred_before).value, field: "occurredBefore")
            return occurred_before if deserializer_result?(occurred_before)

            subject_types = optional_subject_types(params)
            return subject_types if deserializer_result?(subject_types)

            success(Input.new(limit:, offset:, actions:, occurred_after:, occurred_before:, subject_types:))
          end

          private

          def pagination_integer(raw, default:, minimum:, maximum: nil)
            return default if raw.nil? || (raw.is_a?(String) && raw.strip.empty?)

            value = raw.is_a?(Integer) ? raw : (Integer(raw, 10) if raw.is_a?(String) && /\A-?\d+\z/.match?(raw.strip))
            return if value.nil? || value < minimum || (maximum && value > maximum)

            value
          rescue ArgumentError
            nil
          end

          # Prefer eventNames[] / event_names[]; singular eventName remains a one-element alias.
          def optional_event_names(params)
            multi = fetch_param(params, :eventNames, :event_names).value
            singular = fetch_param(params, :eventName, :event_name).value
            normalize_token_list(
              multi,
              singular,
              regex: EVENT_NAME,
              invalid_message: "invalid_eventName",
              too_many_message: "invalid_eventNames"
            )
          end

          def optional_subject_types(params)
            multi = fetch_param(params, :subjectTypes, :subject_types).value
            singular = fetch_param(params, :subjectType, :subject_type).value
            normalize_token_list(
              multi,
              singular,
              regex: SUBJECT_TYPE,
              invalid_message: "invalid_subjectType",
              too_many_message: "invalid_subjectTypes"
            )
          end

          def normalize_token_list(multi, singular, regex:, invalid_message:, too_many_message:)
            raw_values =
              if multi.nil? || (multi.is_a?(String) && multi.strip.empty?)
                singular.nil? || (singular.is_a?(String) && singular.strip.empty?) ? [] : [singular]
              elsif multi.is_a?(Array)
                multi
              elsif multi.is_a?(String)
                [multi]
              else
                return failure(errors: { message: too_many_message })
              end

            tokens = []
            raw_values.each do |raw|
              next if raw.nil? || (raw.is_a?(String) && raw.strip.empty?)
              return failure(errors: { message: invalid_message }) unless raw.is_a?(String) && regex.match?(raw.strip)

              tokens << raw.strip
            end

            tokens = tokens.uniq
            return failure(errors: { message: too_many_message }) if tokens.length > MAX_MULTI

            tokens
          end

          def optional_time(raw, field:)
            return if raw.nil? || (raw.is_a?(String) && raw.strip.empty?)
            return failure(errors: { message: "invalid_#{field}" }) unless raw.is_a?(String)

            Time.iso8601(raw.strip)
          rescue ArgumentError
            failure(errors: { message: "invalid_#{field}" })
          end

          def optional_positive_integer(raw, field:)
            return if raw.nil? || (raw.is_a?(String) && raw.strip.empty?)

            value = raw.is_a?(Integer) ? raw : (Integer(raw, 10) if raw.is_a?(String) && /\A\d+\z/.match?(raw.strip))
            return failure(errors: { message: "invalid_#{field}" }) unless value&.positive?

            value
          rescue ArgumentError
            failure(errors: { message: "invalid_#{field}" })
          end
        end

        class AdminListDeserializer < UserListDeserializer
          Input = Data.define(
            :limit,
            :offset,
            :actions,
            :occurred_after,
            :occurred_before,
            :subject_types,
            :affected_user_id,
            :actor_user_id,
            :originating_administrator_id,
            :attribution_mode,
            :scope_value
          )
          TOOL_ID = "audit"

          def call(params)
            base = super
            return base unless base.success?

            affected_user_id = optional_positive_integer(
              fetch_param(params, :affectedUserId, :affected_user_id).value,
              field: "affectedUserId"
            )
            return affected_user_id if deserializer_result?(affected_user_id)

            actor_user_id = optional_positive_integer(
              fetch_param(params, :actorUserId, :actor_user_id).value,
              field: "actorUserId"
            )
            return actor_user_id if deserializer_result?(actor_user_id)

            originating_administrator_id = optional_positive_integer(
              fetch_param(params, :originatingAdministratorId, :originating_administrator_id).value,
              field: "originatingAdministratorId"
            )
            return originating_administrator_id if deserializer_result?(originating_administrator_id)

            attribution_mode = optional_attribution_mode(fetch_param(params, :attributionMode, :attribution_mode).value)
            return attribution_mode if deserializer_result?(attribution_mode)

            scope_value = CommandTower::Deserializers::Admin::ScopeParameter.extract(params, tool_id: TOOL_ID)

            success(
              Input.new(
                limit: base.input.limit,
                offset: base.input.offset,
                actions: base.input.actions,
                occurred_after: base.input.occurred_after,
                occurred_before: base.input.occurred_before,
                subject_types: base.input.subject_types,
                affected_user_id:,
                actor_user_id:,
                originating_administrator_id:,
                attribution_mode:,
                scope_value:
              )
            )
          end

          private

          def optional_attribution_mode(raw)
            return if raw.nil? || (raw.is_a?(String) && raw.strip.empty?)
            unless raw.is_a?(String) && CommandTower::Audit::Event::ATTRIBUTION_MODES.include?(raw.strip)
              return failure(errors: { message: "invalid_attributionMode" })
            end

            raw.strip
          end
        end

        class ShowDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:id, :scope_value)
          TOOL_ID = "audit"

          def call(params)
            id = optional_positive_integer(fetch_param(params, :id).value, field: "id")
            return id if deserializer_result?(id)
            return failure(errors: { message: "invalid_id" }) if id.nil?

            scope_value = CommandTower::Deserializers::Admin::ScopeParameter.extract(params, tool_id: TOOL_ID)

            success(Input.new(id:, scope_value:))
          end

          private

          def optional_positive_integer(raw, field:)
            return if raw.nil? || (raw.is_a?(String) && raw.strip.empty?)

            value = raw.is_a?(Integer) ? raw : (Integer(raw, 10) if raw.is_a?(String) && /\A\d+\z/.match?(raw.strip))
            return failure(errors: { message: "invalid_#{field}" }) unless value&.positive?

            value
          rescue ArgumentError
            failure(errors: { message: "invalid_#{field}" })
          end
        end
      end
    end
  end
end
