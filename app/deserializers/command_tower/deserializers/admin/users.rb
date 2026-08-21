# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Admin
      module Users
        module IdentityId
          module_function

          def coerce(raw)
            return raw if raw.is_a?(Integer) && raw.positive?
            return if raw.nil?

            text = raw.to_s.strip
            return if text.empty? || !/\A\d+\z/.match?(text)

            Integer(text, 10).then { |value| value.positive? ? value : nil }
          rescue ArgumentError
            nil
          end
        end

        class ListDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:limit, :offset, :search, :scope_value)
          DEFAULT_LIMIT = 50
          MAX_LIMIT = 100
          MAX_SEARCH_LENGTH = 100
          TOOL_ID = "users"

          def call(params)
            limit = pagination_integer(
              fetch_param(params, :limit).value,
              default: DEFAULT_LIMIT,
              minimum: 1,
              maximum: MAX_LIMIT
            )
            return failure(errors: { message: "invalid_limit" }) if limit.nil?

            offset = pagination_integer(fetch_param(params, :offset).value, default: 0, minimum: 0)
            return failure(errors: { message: "invalid_offset" }) if offset.nil?

            search = optional_search(fetch_param(params, :search).value)
            return search if deserializer_result?(search)

            scope_value = CommandTower::Deserializers::Admin::ScopeParameter.extract(params, tool_id: TOOL_ID)

            success(Input.new(limit:, offset:, search:, scope_value:))
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

          # Returns nil, a trimmed String, or a DeserializerResult failure.
          def optional_search(raw)
            return nil if raw.nil?

            text = raw.to_s.strip
            return nil if text.empty?
            return failure(errors: { message: "invalid_search" }) if text.length > MAX_SEARCH_LENGTH

            text
          end
        end

        class ShowDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:id, :scope_value)
          TOOL_ID = "users"

          def call(params)
            id = IdentityId.coerce(fetch_param(params, :id).value)
            return failure(errors: { message: "invalid_id" }) if id.nil?

            scope_value = CommandTower::Deserializers::Admin::ScopeParameter.extract(params, tool_id: TOOL_ID)

            success(Input.new(id:, scope_value:))
          end
        end

        class UpdateNameDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:id, :first_name, :last_name, :scope_value)

          def call(params)
            id = IdentityId.coerce(fetch_param(params, :id).value)
            return failure(errors: { message: "invalid_id" }) if id.nil?

            first_name = fetch_param(params, :first_name, :firstName).value.to_s.strip
            last_name = fetch_param(params, :last_name, :lastName).value.to_s.strip
            if first_name.blank? || last_name.blank?
              return failure(errors: { message: "missing_required_fields" })
            end

            success(
              Input.new(
                id:,
                first_name:,
                last_name:,
                scope_value: CommandTower::Deserializers::Admin::ScopeParameter.extract(params, tool_id: ShowDeserializer::TOOL_ID)
              )
            )
          end
        end

        class UpdateUsernameDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:id, :username, :scope_value)

          def call(params)
            id = IdentityId.coerce(fetch_param(params, :id).value)
            return failure(errors: { message: "invalid_id" }) if id.nil?

            username = fetch_param(params, :username).value.to_s.strip
            return failure(errors: { message: "missing_required_fields" }) if username.blank?

            success(
              Input.new(
                id:,
                username:,
                scope_value: CommandTower::Deserializers::Admin::ScopeParameter.extract(params, tool_id: ShowDeserializer::TOOL_ID)
              )
            )
          end
        end

        class UpdateEmailDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:id, :email, :scope_value)

          def call(params)
            id = IdentityId.coerce(fetch_param(params, :id).value)
            return failure(errors: { message: "invalid_id" }) if id.nil?

            email = fetch_param(params, :email).value.to_s.strip
            return failure(errors: { message: "missing_required_fields" }) if email.blank?

            success(
              Input.new(
                id:,
                email:,
                scope_value: CommandTower::Deserializers::Admin::ScopeParameter.extract(params, tool_id: ShowDeserializer::TOOL_ID)
              )
            )
          end
        end

        class UpdateEmailValidationDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:id, :email_validated, :scope_value)

          def call(params)
            id = IdentityId.coerce(fetch_param(params, :id).value)
            return failure(errors: { message: "invalid_id" }) if id.nil?

            email_validated = coerce_boolean(fetch_param(params, :emailValidated, :email_validated).value)
            return failure(errors: { message: "invalid_email_validated" }) if email_validated.nil?

            success(
              Input.new(
                id:,
                email_validated:,
                scope_value: CommandTower::Deserializers::Admin::ScopeParameter.extract(params, tool_id: ShowDeserializer::TOOL_ID)
              )
            )
          end

          private

          def coerce_boolean(raw)
            case raw
            when true, false
              raw
            when "true", "1", 1
              true
            when "false", "0", 0
              false
            end
          end
        end

        class UpdateRolesDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:id, :roles, :scope_value)

          def call(params)
            id = IdentityId.coerce(fetch_param(params, :id).value)
            return failure(errors: { message: "invalid_id" }) if id.nil?

            raw = fetch_param(params, :roles).value
            unless raw.is_a?(Array)
              return failure(errors: { message: "invalid_roles" })
            end

            roles = raw.map { |value| value.to_s.strip }
            if roles.any?(&:blank?)
              return failure(errors: { message: "invalid_roles" })
            end

            success(
              Input.new(
                id:,
                roles:,
                scope_value: CommandTower::Deserializers::Admin::ScopeParameter.extract(
                  params,
                  tool_id: ShowDeserializer::TOOL_ID
                )
              )
            )
          end
        end
      end
    end
  end
end
