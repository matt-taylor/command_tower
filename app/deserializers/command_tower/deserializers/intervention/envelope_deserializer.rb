# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Intervention
      # Parses a canonical intervention envelope from untrusted params/JSON.
      class EnvelopeDeserializer < CommandTower::Deserializers::ApplicationDeserializer
        Input = Data.define(:action, :allowed, :blockers)

        def call(params)
          source = normalize_source(params)
          action = required_text(source[:action] || source["action"], field: "action")
          return action if deserializer_result?(action)

          allowed_raw = source[:allowed].nil? ? source["allowed"] : source[:allowed]
          allowed = allowed_raw == true || allowed_raw.to_s == "true"

          blockers_raw = source[:blockers] || source["blockers"] || []
          unless blockers_raw.is_a?(Array)
            return failure(errors: [{ field: "blockers", code: "invalid_type", message: "must be an array" }])
          end

          blockers = []
          blockers_raw.each_with_index do |row, index|
            parsed = parse_blocker(row, index)
            return parsed if deserializer_result?(parsed)

            blockers << parsed
          end

          success(Input.new(action: action, allowed: allowed, blockers: blockers))
        end

        private

        def normalize_source(params)
          return params.to_unsafe_h if params.respond_to?(:to_unsafe_h)
          return params.to_h if params.respond_to?(:to_h)

          params.is_a?(Hash) ? params : {}
        end

        def required_text(raw, field:)
          value = raw.is_a?(String) ? raw.strip : raw.to_s.strip
          if value.empty?
            return failure(errors: [{ field: field, code: "missing_required_fields", message: "is required" }])
          end

          value
        end

        def parse_blocker(row, index)
          unless row.is_a?(Hash)
            return failure(
              errors: [{ field: "blockers[#{index}]", code: "invalid_type", message: "must be an object" }]
            )
          end

          code = required_text(row[:code] || row["code"], field: "blockers[#{index}].code")
          return code if deserializer_result?(code)

          action = required_text(row[:action] || row["action"], field: "blockers[#{index}].action")
          return action if deserializer_result?(action)

          title = required_text(row[:title] || row["title"], field: "blockers[#{index}].title")
          return title if deserializer_result?(title)

          message = required_text(row[:message] || row["message"], field: "blockers[#{index}].message")
          return message if deserializer_result?(message)

          blocker = {
            code: code,
            action: action,
            title: title,
            message: message
          }

          severity = row[:severity] || row["severity"]
          blocker[:severity] = severity.to_s if severity.present?

          remediation_raw = row[:remediation] || row["remediation"]
          if remediation_raw.present?
            remediation = parse_remediation(remediation_raw, index)
            return remediation if deserializer_result?(remediation)

            blocker[:remediation] = remediation
          end

          blocker
        end

        def parse_remediation(row, index)
          unless row.is_a?(Hash)
            return failure(
              errors: [
                { field: "blockers[#{index}].remediation", code: "invalid_type", message: "must be an object" }
              ]
            )
          end

          kind = required_text(row[:kind] || row["kind"], field: "blockers[#{index}].remediation.kind")
          return kind if deserializer_result?(kind)

          action = required_text(row[:action] || row["action"], field: "blockers[#{index}].remediation.action")
          return action if deserializer_result?(action)

          remediation = { kind: kind, action: action }
          label = row[:label] || row["label"]
          remediation[:label] = label.to_s if label.present?
          remediation
        end
      end
    end
  end
end
